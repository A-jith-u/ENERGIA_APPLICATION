"""
Application entrypoint that mounts auth and model APIs into a single FastAPI app.
This allows the Docker image to expose a single HTTP service for auth, model, and health checks.
"""
from fastapi import FastAPI

# Use package-relative imports so the module works when run as
# `python -m uvicorn backend.app_main:app` or inside Docker.
from . import auth_api

# Import model app lazily: it's optional for dev (heavy ML deps may be absent).
try:
    from . import serve_prophet
    _model_app = serve_prophet.app
except Exception as _err:
    _model_app = None
    _model_import_error = _err

app = FastAPI(title="ENERGIA Backend")

# Mount sub-apps on distinct prefixes so endpoints don't collide.
# Auth endpoints will be available at /auth/* and model endpoints at /model/*
app.mount("/auth", auth_api.app)
if _model_app is not None:
    app.mount("/model", _model_app)
else:
    @app.get("/model/status")
    def model_status():
        return {"available": False, "error": str(_model_import_error)}


@app.get("/ping")
def ping():
    return {"status": "pong"}
