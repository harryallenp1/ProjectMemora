# Memora ML (UC-03)

Two models that make UC-03 Personalized Memory and Emotional Support adaptive,
served to the Flutter app from Google Cloud Run.

| Model | Question | Method | Result on unseen days |
| --- | --- | --- | --- |
| Anxiety risk | Will this patient be upset in the next hour? | Gradient-boosted trees (scikit-learn), chosen over logistic regression on validation | ROC-AUC 0.72 vs 0.64 for the patient's weekly rate |
| Comfort memory recommender | Which memory is most likely to help right now? | Thompson sampling, priors learned per relationship type | 72% of memories rated "Better" vs 48% random, 76% best possible |

Full numbers: `reports/metrics.json`. Charts: run `python train.py` to create `reports/*.png`.

## Folder

```
memora_ml/features.py      features shared by training and the API (no training/serving skew)
memora_ml/simulate.py      simulated patients for cold start, every assumption documented
memora_ml/recommender.py   Thompson sampling recommender
train.py                   trains, evaluates, saves models/ and reports/ (models/ is not committed)
app/main.py                FastAPI service: /v1/risk, /v1/recommend, /v1/insights, /health
tests/                     pytest
Dockerfile                 Cloud Run image; trains the model during the build (fixed seed, same model every time)
```

## Run locally

```bash
cd ml
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
python train.py                       # creates models/ and reports/ (run before the tests)
pytest -q
uvicorn app.main:app --reload --port 8080
# open http://localhost:8080/docs to try the endpoints
```

Run the app against it (Android emulator reaches your laptop at 10.0.2.2):

```bash
flutter run --dart-define=ML_API_URL=http://10.0.2.2:8080
```

Android blocks plain `http://` outside debug builds; Cloud Run is `https://`, so
that only matters locally.

## Deploy to Cloud Run

Needs the team's GCP project (Blaze plan) and the gcloud CLI.

```bash
cd ml
gcloud config set project <PROJECT_ID>
gcloud run deploy memora-ml --source . --region northamerica-northeast2 \
  --allow-unauthenticated --min-instances 0 --max-instances 2 --memory 512Mi \
  --set-env-vars API_KEY=<pick-a-random-key>
```

Then start the app with:

```bash
flutter run --dart-define=ML_API_URL=https://memora-ml-xxxxx.run.app --dart-define=ML_API_KEY=<same key>
```

`min-instances 0` keeps it inside the free tier; the first request after a quiet
period takes a few seconds (cold start), which is why the app falls back to its
rule when a call times out.

## How the app uses it

- Patient reports a distress mood → `/v1/recommend` picks the memory → app asks
  "Do you feel better?" and saves the answer to Firestore (`memoryReactions`).
- Patient opens My Memories → `/v1/risk`; if high, the app offers a memory
  (at most once every 2 hours).
- Caregiver opens Insights → `/v1/insights` → risk by hour, hardest time of day,
  memories that help most.

The service is stateless: the app sends the last week of moods and the ratings
with each call, so no patient data is stored on Cloud Run.

## Retraining

`python train.py --input <folder>` retrains on CSV exports of Firestore
(`moods.csv`, `missed_routines.csv`, `memories.csv`, `reactions.csv`). The
recommender already learns live from every rating; the risk model is retrained
when enough real check-ins exist. A Cloud Scheduler job can run this weekly.

## Limits to state in the defense

- Trained on simulated data until real check-ins exist; the simulation's
  assumptions are listed at the top of `memora_ml/simulate.py`.
- Predictions suggest a memory; they never block the patient or diagnose anything.
- Missed routines (UC-02) are a model input; the app sends none until UC-02
  stores missed reminders.
