# Memora ML API for Google Cloud Run.
FROM python:3.12-slim

WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY memora_ml ./memora_ml
COPY app ./app
COPY train.py .

# Train during the build: the seed is fixed, so every build makes the same model.
RUN python train.py --no-plots && rm -rf data

ENV PORT=8080 MODEL_DIR=/srv/models
# Cloud Run sends traffic to $PORT.
CMD exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT}
