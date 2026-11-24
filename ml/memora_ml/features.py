"""Feature engineering shared by training and the prediction API.

Both the training script and the Cloud Run service call `risk_features`, so
the model always sees features computed the same way (no training/serving skew).

Inputs are what the app already stores in Firestore:
  * mood entries (timestamp + mood word) from UC-03
  * missed routine reminders (timestamps) from UC-02
"""
from __future__ import annotations

import bisect
import math
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Sequence

# Must match MoodEntry.comfortMoods in lib/features/memory/domain/mood_entry.dart
DISTRESS_MOODS = frozenset({"anxious", "sad", "confused", "lonely", "scared"})

FEATURE_NAMES = [
    "hour",
    "hour_sin",
    "hour_cos",
    "day_of_week",
    "is_weekend",
    "entries_24h",
    "distress_24h",
    "distress_rate_7d",
    "same_hour_distress_rate_7d",
    "hours_since_last_distress",
    "last_entry_distress",
    "missed_routines_today",
]

MAX_HOURS_SINCE = 168.0  # one week cap


def is_distress(mood: str) -> bool:
    return mood.strip().lower() in DISTRESS_MOODS


@dataclass(frozen=True)
class MoodEvent:
    timestamp: datetime
    mood: str

    @property
    def distress(self) -> bool:
        return is_distress(self.mood)


class History:
    """A patient's mood history, sorted by time, with fast 'before t' lookups."""

    def __init__(self, events: Sequence[MoodEvent], missed_routines: Sequence[datetime] = ()):
        self.events = sorted(events, key=lambda e: e.timestamp)
        self.times = [e.timestamp for e in self.events]
        self.missed = sorted(missed_routines)

    def before(self, at: datetime) -> int:
        """Number of events strictly before `at`."""
        return bisect.bisect_left(self.times, at)


def _smoothed_rate(distress: int, total: int) -> float:
    # Laplace-style smoothing so a patient with 1 entry isn't scored 0% or 100%.
    return (distress + 1.0) / (total + 3.0)


def risk_features(history: History, at: datetime) -> list[float]:
    """Features describing the patient's state just before time `at`.

    Only uses information strictly before `at`, so it can be used both to label
    past entries for training and to predict the future at serving time.
    """
    end = history.before(at)
    past = history.events[:end]

    day_ago = at - timedelta(hours=24)
    week_ago = at - timedelta(days=7)
    start_24 = bisect.bisect_left(history.times, day_ago, 0, end)
    start_7d = bisect.bisect_left(history.times, week_ago, 0, end)

    last_24 = past[start_24:]
    last_7d = past[start_7d:]

    distress_24 = sum(e.distress for e in last_24)
    distress_7d = sum(e.distress for e in last_7d)

    same_hour = [e for e in last_7d if abs(e.timestamp.hour - at.hour) <= 1]
    same_hour_distress = sum(e.distress for e in same_hour)

    hours_since = MAX_HOURS_SINCE
    for e in reversed(past):
        if e.distress:
            hours_since = min((at - e.timestamp).total_seconds() / 3600.0, MAX_HOURS_SINCE)
            break

    last_entry_distress = 0.0
    if past and (at - past[-1].timestamp) <= timedelta(hours=6) and past[-1].distress:
        last_entry_distress = 1.0

    day_start = at.replace(hour=0, minute=0, second=0, microsecond=0)
    lo = bisect.bisect_left(history.missed, day_start)
    hi = bisect.bisect_left(history.missed, at)
    missed_today = float(hi - lo)

    hour = at.hour + at.minute / 60.0
    angle = 2 * math.pi * hour / 24.0
    dow = at.weekday()

    return [
        float(at.hour),
        math.sin(angle),
        math.cos(angle),
        float(dow),
        1.0 if dow >= 5 else 0.0,
        float(len(last_24)),
        float(distress_24),
        _smoothed_rate(distress_7d, len(last_7d)),
        _smoothed_rate(same_hour_distress, len(same_hour)),
        hours_since,
        last_entry_distress,
        missed_today,
    ]


def explain(features: list[float]) -> list[str]:
    """Plain-language signals behind a risk score, for the caregiver screen.

    These describe the inputs that raised the score; they are not a diagnosis.
    """
    f = dict(zip(FEATURE_NAMES, features))
    reasons: list[str] = []
    if f["same_hour_distress_rate_7d"] >= 0.45:
        reasons.append("Often upset around this time of day this week")
    if f["last_entry_distress"]:
        reasons.append("Was upset at the last check-in")
    if f["missed_routines_today"] >= 1:
        n = int(f["missed_routines_today"])
        reasons.append(f"Missed {n} routine{'s' if n != 1 else ''} today")
    if f["distress_24h"] >= 2:
        reasons.append(f"Upset {int(f['distress_24h'])} times in the last 24 hours")
    if 15 <= f["hour"] <= 19:
        reasons.append("Late afternoon, when confusion often rises")
    return reasons
