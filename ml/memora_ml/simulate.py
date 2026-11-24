"""Simulated patients, used to train the models before real data exists (cold start).

Every number here is an assumption, written down so it can be defended:

* Each patient has a personal baseline level of distress.
* Distress rises in the late afternoon ("sundowning", peak about 5 pm) by a
  patient-specific amount, and a little in the early morning.
* Weekends (family visits) lower distress for some patients.
* Each missed routine reminder (UC-02) raises distress for the rest of that day.
* Distress persists: being upset one hour makes the next hour more likely.
* Patients log a mood more often when upset (85%) than when fine (40%).

Memories: each patient has 6-10 memories. How well a memory comforts depends on
the patient, its relationship type (family photos help most on average), and a
random personal effect, so some memories work for one patient and not another.
That hidden effectiveness is what the recommender has to learn.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import datetime, timedelta

import numpy as np

DISTRESS_WORDS = ["anxious", "confused", "sad", "lonely", "scared"]
DISTRESS_WEIGHTS = [0.45, 0.25, 0.15, 0.10, 0.05]
CALM_WORDS = ["calm", "happy"]

RELATIONSHIPS = ["daughter", "son", "spouse", "grandchild", "friend", "place", "pet"]
# Average effect of a memory type on feeling better (log-odds), an assumption.
RELATIONSHIP_EFFECT = {
    "daughter": 0.6, "son": 0.6, "spouse": 0.7, "grandchild": 0.8,
    "friend": 0.1, "place": 0.0, "pet": 0.5,
}


def sigmoid(x: float) -> float:
    return 1.0 / (1.0 + math.exp(-x))


_CATEGORY_WORDS = {
    "spouse": {"spouse", "wife", "husband", "partner"},
    "grandchild": {"grandchild", "granddaughter", "grandson"},
    "family": {"daughter", "son", "mother", "father", "mom", "dad", "sister",
               "brother", "niece", "nephew", "aunt", "uncle", "cousin"},
    "friend": {"friend", "neighbour", "neighbor"},
    "pet": {"pet", "dog", "cat"},
    "place": {"place", "home", "trip", "holiday"},
}


def relationship_category(relationship: str) -> str:
    """Groups the free-text relationship a caregiver types into a few categories."""
    r = relationship.strip().lower()
    for category, words in _CATEGORY_WORDS.items():
        if r in words:
            return category
    return "other"


@dataclass
class SimMemory:
    memory_id: str
    relationship: str
    p_better: float  # hidden true effectiveness


@dataclass
class SimPatient:
    patient_id: str
    base: float
    sundown: float
    weekend_relief: float
    routine_sensitivity: float
    persistence: float
    memories: list[SimMemory] = field(default_factory=list)


def make_patients(n: int, rng: np.random.Generator) -> list[SimPatient]:
    patients = []
    for i in range(n):
        p = SimPatient(
            patient_id=f"sim-{i:03d}",
            base=rng.normal(-2.0, 0.6),
            sundown=rng.uniform(0.0, 2.0),
            weekend_relief=rng.uniform(0.0, 0.7),
            routine_sensitivity=rng.uniform(0.2, 0.8),
            persistence=rng.uniform(0.5, 1.6),
        )
        patient_effect = rng.normal(0.0, 0.4)
        for m in range(rng.integers(6, 11)):
            rel = RELATIONSHIPS[rng.integers(len(RELATIONSHIPS))]
            p_better = sigmoid(-0.3 + patient_effect + RELATIONSHIP_EFFECT[rel] + rng.normal(0, 0.9))
            p.memories.append(SimMemory(f"{p.patient_id}-m{m}", rel, p_better))
        patients.append(p)
    return patients


def simulate(n_patients: int = 40, days: int = 90, seed: int = 7,
             start: datetime = datetime(2026, 6, 1)):
    """Returns (moods, missed, memories, reactions) as lists of dicts."""
    rng = np.random.default_rng(seed)
    patients = make_patients(n_patients, rng)
    moods, missed, reactions = [], [], []

    for p in patients:
        prev_distress = 0
        for d in range(days):
            day = start + timedelta(days=d)
            weekend = day.weekday() >= 5
            miss_hours = sorted(rng.integers(8, 21, size=rng.poisson(0.8)).tolist())
            for h in miss_hours:
                missed.append({"patientId": p.patient_id,
                               "timestamp": day + timedelta(hours=int(h), minutes=int(rng.integers(0, 60)))})
            for hour in range(7, 22):
                missed_so_far = sum(1 for h in miss_hours if h < hour)
                logit = (p.base
                         + p.sundown * math.exp(-((hour - 17) / 1.8) ** 2)
                         + 0.4 * math.exp(-((hour - 8) / 1.0) ** 2)
                         - (p.weekend_relief if weekend else 0.0)
                         + p.routine_sensitivity * missed_so_far
                         + p.persistence * prev_distress
                         + rng.normal(0, 0.4))
                distress = int(rng.random() < sigmoid(logit))
                prev_distress = distress
                if rng.random() >= (0.85 if distress else 0.40):
                    continue
                ts = day + timedelta(hours=hour, minutes=int(rng.integers(0, 60)))
                word = (rng.choice(DISTRESS_WORDS, p=DISTRESS_WEIGHTS) if distress
                        else rng.choice(CALM_WORDS))
                moods.append({"patientId": p.patient_id, "timestamp": ts, "mood": str(word)})
                if distress:
                    # Historical data: the old app picked a memory at random.
                    mem = p.memories[rng.integers(len(p.memories))]
                    reactions.append(draw_reaction(p, mem, str(word), ts, rng))
            prev_distress = 0  # night resets

    memories = [{"patientId": p.patient_id, "memoryId": m.memory_id,
                 "relationship": m.relationship, "pBetter": m.p_better}
                for p in patients for m in p.memories]
    return moods, missed, memories, reactions


def draw_reaction(p: SimPatient, mem: SimMemory, mood_before: str, ts: datetime,
                  rng: np.random.Generator) -> dict:
    r = rng.random()
    if r < mem.p_better:
        reaction = "better"
    elif r < mem.p_better + (1 - mem.p_better) * 0.3:
        reaction = "worse"
    else:
        reaction = "same"
    return {"patientId": p.patient_id, "memoryId": mem.memory_id,
            "relationship": mem.relationship, "moodBefore": mood_before,
            "reaction": reaction, "timestamp": ts + timedelta(minutes=2)}
