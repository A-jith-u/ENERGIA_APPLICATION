Prophet model service (minimal)

Files:
- `train_prophet.py` - train model from Postgres or CSV and save `models/prophet_model.joblib`
- `serve_prophet.py` - FastAPI app exposing `/predict_next_hour` and `/health`
- `mqtt_ingest.py` - example MQTT -> Postgres ingestor
- `Dockerfile` - container image for serving and training
- `requirements.txt` - Python dependencies

Quick start (using Docker Compose recommended):

1. Build image and run service (example):
   ```bash
   docker build -t energia-prophet -f backend/Dockerfile backend
   docker run --rm -p 8000:8000 -e MODEL_PATH=/app/models/prophet_model.joblib energia-prophet
   ```

2. Train model (if you have CSV locally):
   ```bash
   python backend/train_prophet.py --csv data/sample_sensor.csv --out backend/models/prophet_model.joblib
   ```

3. Call prediction endpoint:
   ```bash
   curl -X POST http://localhost:8000/predict_next_hour -H "Content-Type: application/json" -d '{"lookback_minutes":60, "freq":"min"}'
   ```

Notes:
- On Windows installing `prophet` locally can be tricky; prefer building the Docker image where the native build requirements are installed in the container.
- Make sure your `sensor_data` table has columns: `ds` (timestamp), `device_id`, `value`.
