"""
Simple script to start the uvicorn server with the correct configuration.
Loads environment from .env if present; validates DB_URL points to PostgreSQL.
"""
import os
import sys
import asyncio
import socket
import uvicorn
from dotenv import load_dotenv

# Add parent directory to path so backend module can be imported
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Load environment from backend/.env first, then fallback to default search.
_here = os.path.dirname(os.path.abspath(__file__))
_backend_env = os.path.join(_here, ".env")
if os.path.exists(_backend_env):
    load_dotenv(dotenv_path=_backend_env, override=False)
else:
    load_dotenv(override=False)

# Import config to validate and fail early if DB_URL is invalid
from backend import config as cfg
cfg.get_db_url()  # This will raise if DB_URL is missing or not PostgreSQL


def _port_available(host: str, port: int) -> bool:
    """Return True when host:port can be bound by this process."""
    test_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        test_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        test_socket.bind((host, port))
        return True
    except OSError:
        return False
    finally:
        test_socket.close()

if __name__ == "__main__":
    # Workaround for intermittent WinError 64 accept-socket exceptions on
    # Python 3.12 + Proactor loop when clients disconnect abruptly.
    if sys.platform.startswith("win"):
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "5000"))

    # Avoid noisy crashes when an instance is already running on this port.
    if not _port_available(host, port):
        print(f"[INFO] Port {port} is already in use. Backend is likely already running.")
        print("[INFO] Stop the existing server first, or set a different PORT.")
        raise SystemExit(0)

    try:
        uvicorn.run(
            "backend.app_main:app",
            host=host,
            port=port,
            reload=False,
            log_level="info"
        )
    except KeyboardInterrupt:
        # Ctrl+C should be a clean, expected shutdown path on local dev.
        print("[INFO] Server stopped by user.")
        raise SystemExit(0)
