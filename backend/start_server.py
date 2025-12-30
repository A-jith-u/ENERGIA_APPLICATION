"""
Simple script to start the uvicorn server with the correct configuration.
Loads environment from .env if present; validates DB_URL points to PostgreSQL.
"""
import os
import sys
import uvicorn
from dotenv import load_dotenv

# Add parent directory to path so backend module can be imported
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Load environment from .env (if present, without overriding real env)
load_dotenv(override=False)

# Import config to validate and fail early if DB_URL is invalid
from backend import config as cfg
cfg.get_db_url()  # This will raise if DB_URL is missing or not PostgreSQL

if __name__ == "__main__":
    uvicorn.run(
        "backend.app_main:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        log_level="info"
    )
