import os
import uvicorn


if __name__ == "__main__":
    host = os.environ.get("HOST", "0.0.0.0")
    port = int(os.environ.get("PORT", "8011"))
    reload_flag = os.environ.get("RELOAD", "false").lower() == "true"

    uvicorn.run(
        "serve_ensemble_90_mixed:app",
        host=host,
        port=port,
        reload=reload_flag,
        log_level="info",
    )
