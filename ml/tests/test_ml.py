from datetime import datetime, timedelta

import numpy as np
import pytest
from fastapi.testclient import TestClient

from app.main import app
from memora_ml.features import FEATURE_NAMES, History, MoodEvent, risk_features
from memora_ml.recommender import Candidate, Reaction, rank
from memora_ml.simulate import relationship_category

client = TestClient(app)
NOW = datetime(2026, 11, 23, 16, 30)


def moods_payload(upset_afternoons: bool):
    rows = []
    for d in range(1, 8):
        day = NOW - timedelta(days=d)
        rows.append({"timestamp": day.replace(hour=9).isoformat(), "mood": "calm"})
        rows.append({"timestamp": day.replace(hour=16).isoformat(),
                     "mood": "anxious" if upset_afternoons else "happy"})
    return rows


# ---------------------------------------------------------------- features

def test_features_use_only_the_past():
    h = History([MoodEvent(NOW - timedelta(hours=1), "anxious"),
                 MoodEvent(NOW + timedelta(minutes=5), "anxious")])
    f = dict(zip(FEATURE_NAMES, risk_features(h, NOW)))
    assert f["entries_24h"] == 1  # the future entry is ignored
    assert f["last_entry_distress"] == 1.0
    assert f["hours_since_last_distress"] == pytest.approx(1.0)


def test_missed_routines_count_only_today():
    h = History([], [NOW - timedelta(days=1), NOW - timedelta(hours=2), NOW - timedelta(hours=1)])
    f = dict(zip(FEATURE_NAMES, risk_features(h, NOW)))
    assert f["missed_routines_today"] == 2


def test_empty_history_is_valid():
    assert len(risk_features(History([]), NOW)) == len(FEATURE_NAMES)


# ---------------------------------------------------------------- recommender

def test_recommender_prefers_memory_that_helped():
    cands = [Candidate("a", "daughter"), Candidate("b", "daughter")]
    reactions = [Reaction("a", "better")] * 5 + [Reaction("b", "worse")] * 5
    top = rank(cands, reactions, {"family": 0.5}, explore=False)
    assert top[0].memory_id == "a"
    assert top[0].reason == "Helped 5 of 5 times"


def test_recommender_still_explores_new_memories():
    cands = [Candidate("proven", "friend"), Candidate("new", "grandchild")]
    reactions = [Reaction("proven", "better")] * 2 + [Reaction("proven", "same")] * 2
    rng = np.random.default_rng(0)
    picks = [rank(cands, reactions, {"friend": 0.4, "grandchild": 0.6}, rng=rng)[0].memory_id
             for _ in range(200)]
    assert 0 < picks.count("new") < 200


def test_relationship_categories():
    assert relationship_category("Granddaughter") == "grandchild"
    assert relationship_category("wife") == "spouse"
    assert relationship_category("Son") == "family"
    assert relationship_category("coworker") == "other"


# ---------------------------------------------------------------- API

def test_health():
    assert client.get("/health").json()["status"] == "ok"


def test_risk_is_higher_for_a_patient_upset_every_afternoon():
    calm = client.post("/v1/risk", json={"patientId": "p1", "at": NOW.isoformat(),
                                         "moods": moods_payload(False)}).json()
    upset = client.post("/v1/risk", json={"patientId": "p1", "at": NOW.isoformat(),
                                          "moods": moods_payload(True),
                                          "missedRoutines": [NOW.replace(hour=11).isoformat()]}).json()
    assert 0 <= calm["risk"] <= 1 and 0 <= upset["risk"] <= 1
    assert upset["risk"] > calm["risk"]
    if upset["level"] == "high":
        assert upset["reasons"]


def test_recommend_ranks_all_memories():
    body = {"patientId": "p1", "mood": "anxious", "explore": False,
            "memories": [{"memoryId": "m1", "relationship": "friend"},
                         {"memoryId": "m2", "relationship": "grandson"}],
            "reactions": [{"memoryId": "m2", "reaction": "better"}] * 3}
    ranked = client.post("/v1/recommend", json=body).json()["ranked"]
    assert [r["memoryId"] for r in ranked] == ["m2", "m1"]


def test_bad_reaction_is_rejected():
    body = {"patientId": "p1", "memories": [{"memoryId": "m1"}],
            "reactions": [{"memoryId": "m1", "reaction": "amazing"}]}
    assert client.post("/v1/recommend", json=body).status_code == 422


def test_insights_shape():
    body = {"patientId": "p1", "at": NOW.isoformat(), "moods": moods_payload(True),
            "memories": [{"memoryId": "m1", "relationship": "daughter"}],
            "reactions": [{"memoryId": "m1", "reaction": "better"}]}
    out = client.post("/v1/insights", json=body).json()
    assert len(out["riskByHour"]) == 15
    assert {p["period"] for p in out["upsetByTimeOfDay"]} == {"Morning", "Afternoon"}
    assert out["bestMemories"][0]["memoryId"] == "m1"
    assert out["summary"]
