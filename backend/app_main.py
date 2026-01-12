"""
Application entrypoint that mounts auth and model APIs into a single FastAPI app.
This allows the Docker image to expose a single HTTP service for auth, model, and health checks.
"""
import importlib
import os
import sys
from fastapi import FastAPI


def _load(name: str):
    """Import backend modules whether run as package or as a bare module."""
    if __package__:
        return importlib.import_module(f".{name}", __package__)
    sys.path.append(os.path.dirname(__file__))
    return importlib.import_module(name)


auth_api = _load("auth_api")
notify_api = _load("notify_api")
recommendation_api = _load("recommendation_api")
activity_log_api = _load("activity_log_api")
monthly_report_api = _load("monthly_report_api")

# Import model app lazily: it's optional for dev (heavy ML deps may be absent).
try:
    serve_prophet = _load("serve_prophet")
    _model_app = serve_prophet.app
except Exception as _err:  # noqa: BLE001
    _model_app = None
    _model_import_error = _err

app = FastAPI(title="ENERGIA Backend")

# Mount sub-apps on distinct prefixes so endpoints don't collide.
# Auth endpoints will be available at /auth/* and model endpoints at /model/*
app.mount("/auth", auth_api.app)
app.mount("/api", auth_api.app)
app.mount("/notify", notify_api.app)
app.mount("/recommendations", recommendation_api.app)
app.mount("/activity", activity_log_api.app)
app.mount("/reports", monthly_report_api.router)
if _model_app is not None:
    app.mount("/model", _model_app)
else:
    @app.get("/model/status")
    def model_status():
        return {"available": False, "error": str(_model_import_error)}


@app.get("/ping")
def ping():
    return {"status": "pong"}
