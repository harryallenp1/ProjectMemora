"""Memora ML API, deployed to Google Cloud Run.

Stateless: the app sends the patient's recent moods and memory ratings with each
request (it already has them from Firestore), so the service keeps no patient
data and can scale to zero between requests.

    uvicorn app.main:app --reload --port 8080     # local
    POST /v1/risk        anxiety risk for the next hour + the signals behind it
    POST /v1/recommend   memories ranked by how likely they are to help now
    POST /v1/insights    data for the caregiver insights screen
    GET  /health
"""
from __future__ import annotations

import json
import os
from datetime import datetime, timedelta
from pathlib import Path
from typing import Literal

import joblib
import numpy as np
from fastapi import Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

from memora_ml.features import History, MoodEvent, explain, risk_features
from memora_ml.recommender import Candidate, Reaction, rank

MODEL_DIR = Path(os.environ.get("MODEL_DIR", Path(__file__).resolve().parent.parent / "models"))
API_KEY = os.environ.get("API_KEY")  # set on Cloud Run; unset locally = no key needed

_artifact = joblib.load(MODEL_DIR / "anxiety_risk.joblib")
_priors: dict[str, float] = json.loads((MODEL_DIR / "recommender_priors.json").read_text())

app = FastAPI(title="Memora ML API", version="1.0.0")


def check_key(x_api_key: str | None = Header(default=None)):
    if API_KEY and x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")


# ---------------------------------------------------------------- schemas

class MoodIn(BaseModel):
    timestamp: datetime
    mood: str = Field(max_length=40)


class MemoryIn(BaseModel):
    memoryId: str = Field(max_length=200)
    relationship: str = Field(default="", max_length=60)


class ReactionIn(BaseModel):
    memoryId: str = Field(max_length=200)
    reaction: Literal["better", "same", "worse"]


class RiskRequest(BaseModel):
    patientId: str = Field(max_length=200)
    at: datetime | None = None
    moods: list[MoodIn] = Field(default_factory=list, max_length=5000)
    missedRoutines: list[datetime] = Field(default_factory=list, max_length=2000)


class RiskResponse(BaseModel):
    risk: float
    level: Literal["high", "low"]
    threshold: float
    reasons: list[str]
    model: str
    modelTrainedAt: str


class RecommendRequest(BaseModel):
    patientId: str = Field(max_length=200)
    mood: str = Field(default="", max_length=40)
    memories: list[MemoryIn] = Field(max_length=1000)
    reactions: list[ReactionIn] = Field(default_factory=list, max_length=10000)
    explore: bool = True


class RankedOut(BaseModel):
    memoryId: str
    expectedHelp: float
    ratings: int
    helped: int
    reason: str


class RecommendResponse(BaseModel):
    ranked: list[RankedOut]


class InsightsRequest(RiskRequest):
    memories: list[MemoryIn] = Field(default_factory=list, max_length=1000)
    reactions: list[ReactionIn] = Field(default_factory=list, max_length=10000)


class HourRisk(BaseModel):
    hour: int
    risk: float


class PeriodRate(BaseModel):
    period: str
    upsetShare: float
    checkIns: int


class InsightsResponse(BaseModel):
    riskByHour: list[HourRisk]
    peakHour: int | None
    upsetByTimeOfDay: list[PeriodRate]
    bestMemories: list[RankedOut]
    summary: list[str]


# ---------------------------------------------------------------- helpers

def _local(t: datetime) -> datetime:
    """Keep the patient's wall-clock time; the hour of day is what matters."""
    return t.replace(tzinfo=None)


def _history(req: RiskRequest) -> History:
    return History([MoodEvent(_local(m.timestamp), m.mood) for m in req.moods],
                   [_local(t) for t in req.missedRoutines])


def _risk(history: History, at: datetime) -> tuple[float, list[float]]:
    x = risk_features(history, at)
    p = float(_artifact["model"].predict_proba(np.array([x]))[0, 1])
    return p, x


def _ranked(memories, reactions, explore) -> list[RankedOut]:
    result = rank([Candidate(m.memoryId, m.relationship) for m in memories],
                  [Reaction(r.memoryId, r.reaction) for r in reactions],
                  _priors, explore=explore)
    return [RankedOut(memoryId=r.memory_id, expectedHelp=r.expected_help,
                      ratings=r.ratings, helped=r.helped, reason=r.reason) for r in result]


PERIODS = [("Morning", 6, 12), ("Afternoon", 12, 17), ("Evening", 17, 22), ("Night", 22, 30)]


def _hour_label(h: int) -> str:
    return f"{h % 12 or 12} {'am' if h < 12 else 'pm'}"


# ---------------------------------------------------------------- routes

@app.get("/health")
def health():
    return {"status": "ok", "model": _artifact["name"], "trainedAt": _artifact["trained_at"]}


@app.post("/v1/risk", response_model=RiskResponse, dependencies=[Depends(check_key)])
def risk(req: RiskRequest):
    at = _local(req.at) if req.at else datetime.now()
    p, x = _risk(_history(req), at)
    threshold = float(_artifact["threshold"])
    return RiskResponse(risk=round(p, 4), level="high" if p >= threshold else "low",
                        threshold=round(threshold, 3), reasons=explain(x) if p >= threshold else [],
                        model=_artifact["name"], modelTrainedAt=_artifact["trained_at"])


@app.post("/v1/recommend", response_model=RecommendResponse, dependencies=[Depends(check_key)])
def recommend(req: RecommendRequest):
    if not req.memories:
        return RecommendResponse(ranked=[])
    return RecommendResponse(ranked=_ranked(req.memories, req.reactions, req.explore))


@app.post("/v1/insights", response_model=InsightsResponse, dependencies=[Depends(check_key)])
def insights(req: InsightsRequest):
    at = _local(req.at) if req.at else datetime.now()
    history = _history(req)
    day = at.replace(hour=0, minute=0, second=0, microsecond=0)

    # Risk for each waking hour today. Features only use events before each hour,
    # and nothing after `at` is known, so later hours are true forecasts.
    known = History([e for e in history.events if e.timestamp <= at],
                    [t for t in history.missed if t <= at])
    curve = []
    for h in range(7, 22):
        p, _ = _risk(known, day + timedelta(hours=h))
        curve.append(HourRisk(hour=h, risk=round(p, 4)))
    peak = max(curve, key=lambda c: c.risk) if curve else None

    recent = [e for e in history.events if at - timedelta(days=14) <= e.timestamp <= at]
    periods = []
    for name, lo, hi in PERIODS:
        group = [e for e in recent if lo <= (e.timestamp.hour if e.timestamp.hour >= 6 else e.timestamp.hour + 24) < hi]
        if group:
            periods.append(PeriodRate(period=name, checkIns=len(group),
                                      upsetShare=round(sum(e.distress for e in group) / len(group), 4)))

    best = _ranked(req.memories, req.reactions, explore=False)[:3] if req.memories else []

    summary = []
    if periods:
        worst = max(periods, key=lambda p: p.upsetShare)
        if worst.upsetShare > 0:
            summary.append(f"{worst.period}s are hardest: upset at {round(worst.upsetShare * 100)}% "
                           f"of check-ins over the last 2 weeks")
    if peak and peak.risk >= _artifact["threshold"]:
        summary.append(f"Highest predicted risk today around {_hour_label(peak.hour)}")
    if best and best[0].ratings:
        summary.append(f"Best comfort memory so far: {best[0].reason.lower()}")

    return InsightsResponse(riskByHour=curve, peakHour=peak.hour if peak else None,
                            upsetByTimeOfDay=periods, bestMemories=best, summary=summary)
