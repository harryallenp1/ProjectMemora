"""Train, evaluate and save both Memora models.

    python train.py                     # simulated data (cold start)
    python train.py --input data/live   # CSV exports from Firestore (retraining)

The Docker build runs `python train.py --no-plots`, so the image always
contains a model trained by this exact code (models/ is not committed).

Writes:
    models/anxiety_risk.joblib   the risk model + its threshold and feature list
    models/recommender_priors.json
    reports/metrics.json         every number quoted in the report / defense
    reports/*.png                charts for the report
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
import sklearn
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (average_precision_score, f1_score, precision_score,
                             recall_score, roc_auc_score, roc_curve)
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

from memora_ml.features import FEATURE_NAMES, History, MoodEvent, risk_features
from memora_ml.recommender import Candidate, Reaction, learn_priors, rank
from memora_ml.simulate import simulate

HERE = Path(__file__).parent
SEED = 7


# ---------------------------------------------------------------- data

def load(input_dir: Path | None):
    if input_dir is None:
        moods, missed, memories, reactions = simulate(seed=SEED)
        out = HERE / "data" / "simulated"
        out.mkdir(parents=True, exist_ok=True)
        for name, rows in [("moods", moods), ("missed_routines", missed),
                           ("memories", memories), ("reactions", reactions)]:
            pd.DataFrame(rows).to_csv(out / f"{name}.csv", index=False)
        return (pd.DataFrame(moods), pd.DataFrame(missed),
                pd.DataFrame(memories), pd.DataFrame(reactions), "simulated")
    read = lambda n: pd.read_csv(input_dir / f"{n}.csv", parse_dates=["timestamp"])  # noqa: E731
    return (read("moods"), read("missed_routines"),
            pd.read_csv(input_dir / "memories.csv"), read("reactions"), str(input_dir))


def build_dataset(moods: pd.DataFrame, missed: pd.DataFrame) -> pd.DataFrame:
    """One row per logged mood: features from everything before it, label = upset?"""
    rows = []
    for pid, group in moods.groupby("patientId"):
        events = [MoodEvent(t.to_pydatetime(), m) for t, m in zip(group["timestamp"], group["mood"])]
        miss = [t.to_pydatetime() for t in missed.loc[missed["patientId"] == pid, "timestamp"]]
        history = History(events, miss)
        for e in history.events:
            rows.append([pid, e.timestamp, *risk_features(history, e.timestamp), int(e.distress)])
    return pd.DataFrame(rows, columns=["patientId", "timestamp", *FEATURE_NAMES, "label"])


# ---------------------------------------------------------------- risk model

def metrics_at(y, p, threshold):
    pred = (p >= threshold).astype(int)
    return {
        "roc_auc": round(roc_auc_score(y, p), 4),
        "pr_auc": round(average_precision_score(y, p), 4),
        "precision": round(precision_score(y, pred, zero_division=0), 4),
        "recall": round(recall_score(y, pred, zero_division=0), 4),
        "f1": round(f1_score(y, pred, zero_division=0), 4),
    }


def best_threshold(y, p):
    grid = np.linspace(0.1, 0.9, 81)
    scores = [f1_score(y, (p >= t).astype(int), zero_division=0) for t in grid]
    return float(grid[int(np.argmax(scores))])


def candidate_models():
    return {
        "logistic_regression": make_pipeline(StandardScaler(), LogisticRegression(max_iter=1000)),
        "gradient_boosting": HistGradientBoostingClassifier(
            max_iter=300, learning_rate=0.05, max_leaf_nodes=15,
            l2_regularization=1.0, random_state=SEED),
    }


def train_risk(data: pd.DataFrame, report: dict):
    start = data["timestamp"].min().normalize()
    day = (data["timestamp"] - start).dt.days
    total_days = int(day.max()) + 1
    test_from = int(total_days * 2 / 3)       # last third = test
    val_from = test_from - total_days // 9    # ~10 days before test = validation

    fit, val = data[day < val_from], data[(day >= val_from) & (day < test_from)]
    train, test = data[day < test_from], data[day >= test_from]
    X = lambda d: d[FEATURE_NAMES].to_numpy()  # noqa: E731

    report["risk_split"] = {
        "train_days": f"0-{test_from - 1}", "test_days": f"{test_from}-{total_days - 1}",
        "train_rows": len(train), "test_rows": len(test),
        "test_distress_rate": round(float(test["label"].mean()), 4),
        "note": "Time-based split: the model is tested only on days after the ones it learned from.",
    }

    # Baselines a caregiver could compute by hand.
    results = {
        "baseline_patient_rate": metrics_at(test["label"], test["distress_rate_7d"],
                                            best_threshold(val["label"], val["distress_rate_7d"])),
        "baseline_same_hour_rate": metrics_at(test["label"], test["same_hour_distress_rate_7d"],
                                              best_threshold(val["label"], val["same_hour_distress_rate_7d"])),
    }

    chosen, chosen_auc, models = None, -1.0, {}
    for name, model in candidate_models().items():
        model.fit(X(fit), fit["label"])
        threshold = best_threshold(val["label"], model.predict_proba(X(val))[:, 1])
        val_auc = roc_auc_score(val["label"], model.predict_proba(X(val))[:, 1])
        model.fit(X(train), train["label"])            # refit on all training days
        p = model.predict_proba(X(test))[:, 1]
        results[name] = {**metrics_at(test["label"], p, threshold), "threshold": round(threshold, 3)}
        models[name] = (model, threshold, p)
        if val_auc > chosen_auc:                        # choose on validation, not test
            chosen, chosen_auc = name, val_auc

    report["risk_results"] = results
    report["risk_chosen_model"] = chosen
    return chosen, models, test


def _plt():
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    return plt


def plot_risk(models, test, chosen, out: Path):
    plt = _plt()
    fig, ax = plt.subplots(figsize=(6, 5))
    for name, (_, _, p) in models.items():
        fpr, tpr, _ = roc_curve(test["label"], p)
        ax.plot(fpr, tpr, label=f"{name.replace('_', ' ')} (AUC {roc_auc_score(test['label'], p):.2f})")
    fpr, tpr, _ = roc_curve(test["label"], test["distress_rate_7d"])
    ax.plot(fpr, tpr, "--", label=f"baseline: patient's weekly rate (AUC {roc_auc_score(test['label'], test['distress_rate_7d']):.2f})")
    ax.plot([0, 1], [0, 1], ":", color="grey")
    ax.set(xlabel="False positive rate", ylabel="True positive rate",
           title="Anxiety risk model on unseen days (test set)")
    ax.legend(fontsize=8, loc="lower right")
    fig.tight_layout()
    fig.savefig(out / "risk_roc.png", dpi=150)
    plt.close(fig)

    p = models[chosen][2]
    by_hour = test.assign(pred=p).groupby("hour").agg(observed=("label", "mean"), predicted=("pred", "mean"))
    fig, ax = plt.subplots(figsize=(7, 4))
    ax.plot(by_hour.index, by_hour["observed"], "o-", label="Observed share of upset check-ins")
    ax.plot(by_hour.index, by_hour["predicted"], "s--", label="Model's average predicted risk")
    ax.set(xlabel="Hour of day", ylabel="Share / risk", title="Risk follows the late-afternoon rise",
           xticks=range(7, 22))
    ax.legend(fontsize=8)
    fig.tight_layout()
    fig.savefig(out / "risk_by_hour.png", dpi=150)
    plt.close(fig)


# ---------------------------------------------------------------- recommender

def simulated_answer(p_better: float, rng) -> str:
    r = rng.random()  # same answer model as simulate.draw_reaction
    return "better" if r < p_better else "worse" if r < p_better + (1 - p_better) * 0.3 else "same"


def evaluate_recommender(reactions: pd.DataFrame, memories: pd.DataFrame, report: dict, out: Path,
                         plots: bool = True):
    """Replays the test period with each policy against the simulated patients.

    In simulation we know each memory's true chance of helping, so every policy
    is scored on the same distress events by the expected share of 'better'.
    """
    if "pBetter" not in memories:
        report["recommender_eval"] = "skipped: needs simulated ground truth"
        return
    start = reactions["timestamp"].min().normalize()
    day = (reactions["timestamp"] - start).dt.days
    cut = int((int(day.max()) + 1) * 2 / 3)
    train_r, test_r = reactions[day < cut], reactions[day >= cut]
    priors = learn_priors(train_r.to_dict("records"))

    rng = np.random.default_rng(SEED)
    totals = {"random": [], "newest_first": [], "current_rule": [], "thompson_sampling": [], "best_possible": []}

    for pid, events in test_r.groupby("patientId"):
        mems = memories[memories["patientId"] == pid]
        truth = dict(zip(mems["memoryId"], mems["pBetter"]))
        cands = [Candidate(m, r) for m, r in zip(mems["memoryId"], mems["relationship"])]
        learned = [Reaction(r.memoryId, r.reaction)
                   for r in train_r[train_r["patientId"] == pid].itertuples()]
        person = [c for c in cands if c.relationship not in ("place",)]
        for e in events.itertuples():
            totals["random"].append(float(np.mean(list(truth.values()))))
            totals["newest_first"].append(truth[cands[-1].memory_id])
            totals["current_rule"].append(truth[(person or cands)[-1].memory_id])
            totals["best_possible"].append(max(truth.values()))
            pick = rank(cands, learned, priors, explore=True, rng=rng)[0].memory_id
            totals["thompson_sampling"].append(truth[pick])
            # The simulated patient answers; the recommender learns online.
            learned.append(Reaction(pick, simulated_answer(truth[pick], rng)))

    results = {k: round(float(np.mean(v)), 4) for k, v in totals.items()}
    report["recommender_eval"] = {
        "metric": "expected share of comfort memories rated 'Better' in the test period",
        "events": len(test_r), **results,
        "lift_vs_random_pct": round((results["thompson_sampling"] / results["random"] - 1) * 100, 1),
    }
    report["recommender_priors"] = priors

    if not plots:
        return
    plt = _plt()
    labels = ["Random", "Newest first", "Current rule", "Thompson sampling", "Best possible"]
    keys = ["random", "newest_first", "current_rule", "thompson_sampling", "best_possible"]
    fig, ax = plt.subplots(figsize=(7, 4))
    bars = ax.bar(labels, [results[k] * 100 for k in keys],
                  color=["#bbb", "#bbb", "#bbb", "#2f6fdb", "#ddd"])
    ax.bar_label(bars, fmt="%.0f%%")
    ax.set(ylabel="Memories rated 'Better' (%)", title="Recommender vs simple rules (test period)")
    fig.tight_layout()
    fig.savefig(out / "recommender.png", dpi=150)
    plt.close(fig)


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", type=Path, default=None, help="folder of Firestore CSV exports")
    ap.add_argument("--no-plots", action="store_true", help="skip charts (used in the Docker build)")
    args = ap.parse_args()

    models_dir, reports_dir = HERE / "models", HERE / "reports"
    models_dir.mkdir(exist_ok=True)
    reports_dir.mkdir(exist_ok=True)

    moods, missed, memories, reactions, source = load(args.input)
    report = {"trained_at": datetime.now().isoformat(timespec="seconds"), "data_source": source,
              "patients": int(moods["patientId"].nunique()), "mood_entries": len(moods),
              "reactions": len(reactions), "sklearn_version": sklearn.__version__}

    data = build_dataset(moods, missed)
    chosen, models, test = train_risk(data, report)
    if not args.no_plots:
        plot_risk(models, test, chosen, reports_dir)

    # Serve the chosen model refit on every row, with the threshold picked on validation.
    final, threshold, _ = models[chosen]
    final.fit(data[FEATURE_NAMES].to_numpy(), data["label"])
    joblib.dump({"model": final, "name": chosen, "threshold": threshold,
                 "feature_names": FEATURE_NAMES, "trained_at": report["trained_at"],
                 "sklearn_version": sklearn.__version__}, models_dir / "anxiety_risk.joblib")

    evaluate_recommender(reactions, memories, report, reports_dir, plots=not args.no_plots)
    priors = learn_priors(reactions.to_dict("records"))  # served priors use all data
    (models_dir / "recommender_priors.json").write_text(json.dumps(priors, indent=2))

    (reports_dir / "metrics.json").write_text(json.dumps(report, indent=2, default=str))
    print(json.dumps({k: report[k] for k in ("risk_chosen_model", "risk_results", "recommender_eval")},
                     indent=2, default=str))


if __name__ == "__main__":
    main()
