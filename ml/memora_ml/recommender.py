"""Comfort memory recommender (Model 2).

Learns which memory helps a patient most, from their Better / Same / Worse
answers after a memory is played.

Method: Thompson sampling over a Beta distribution per memory.
  * Prior: how often memories of the same relationship type helped across all
    patients in training (in the simulated data, spouse photos helped ~58%). New
    memories therefore start with a sensible guess instead of zero.
  * Each "better" adds a success; "worse" adds a failure; "same" half a failure.
  * To rank, we draw one sample from each memory's Beta and sort. Memories with
    few ratings get wider draws, so they are still tried now and then
    (exploration) while proven memories are shown most often (exploitation).
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

import numpy as np

from .simulate import relationship_category

PRIOR_STRENGTH = 4.0      # prior counts as 4 "virtual" ratings
DEFAULT_PRIOR_RATE = 0.5  # used if a category was never seen in training


@dataclass
class Candidate:
    memory_id: str
    relationship: str = ""


@dataclass
class Reaction:
    memory_id: str
    reaction: str  # better | same | worse


@dataclass
class Ranked:
    memory_id: str
    score: float          # the value used for ranking (a sample or the mean)
    expected_help: float  # posterior mean chance of "better"
    ratings: int
    helped: int
    reason: str


def learn_priors(reactions: Iterable[dict]) -> dict[str, float]:
    """Share of 'better' answers per relationship category in the training data."""
    counts: dict[str, list[int]] = {}
    for r in reactions:
        c = counts.setdefault(relationship_category(r["relationship"]), [0, 0])
        c[0] += r["reaction"] == "better"
        c[1] += 1
    return {cat: round((b + 1) / (n + 2), 4) for cat, (b, n) in counts.items()}


def rank(candidates: list[Candidate], reactions: list[Reaction], priors: dict[str, float],
         explore: bool = True, rng: np.random.Generator | None = None) -> list[Ranked]:
    rng = rng or np.random.default_rng()
    by_memory: dict[str, list[str]] = {}
    for r in reactions:
        by_memory.setdefault(r.memory_id, []).append(r.reaction.strip().lower())

    out: list[Ranked] = []
    for c in candidates:
        category = relationship_category(c.relationship)
        prior = priors.get(category, priors.get("other", DEFAULT_PRIOR_RATE))
        alpha = 1.0 + PRIOR_STRENGTH * prior
        beta = 1.0 + PRIOR_STRENGTH * (1.0 - prior)
        history = by_memory.get(c.memory_id, [])
        helped = sum(1 for x in history if x == "better")
        alpha += helped
        beta += sum(1.0 if x == "worse" else 0.5 if x == "same" else 0.0 for x in history)

        mean = alpha / (alpha + beta)
        score = float(rng.beta(alpha, beta)) if explore else mean
        if history:
            reason = f"Helped {helped} of {len(history)} times"
        else:
            label = category if category != "other" else "these"
            reason = f"New memory; {label} memories help about {round(prior * 100)}% of the time"
        out.append(Ranked(c.memory_id, score, round(mean, 4), len(history), helped, reason))

    out.sort(key=lambda r: r.score, reverse=True)
    return out
