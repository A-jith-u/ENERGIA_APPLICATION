"""
Simple script to start the uvicorn server with the correct configuration
"""
import os
import sys
import uvicorn

# Add parent directory to path so backend module can be imported
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Set the database URL
os.environ["DB_URL"] = "postgresql://postgres:ajith%40@localhost:5432/energia"

if __name__ == "__main__":
    uvicorn.run(
        "backend.app_main:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        log_level="info"
    )
