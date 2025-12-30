"""
Recommendations API - Dynamic, context-aware recommendations for all user types
"""
import os
import sys
import importlib
from typing import Optional
from fastapi import FastAPI, HTTPException, Depends, Header
from pydantic import BaseModel
import jwt

# Load config
def _load_cfg():
    if __package__:
        from . import config
        return config
    else:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        return importlib.import_module("config")

def _load_engine():
    if __package__:
        from . import recommendation_engine
        return recommendation_engine
    else:
        return importlib.import_module("recommendation_engine")

cfg = _load_cfg()
rec_engine_module = _load_engine()

app = FastAPI(title="Recommendations Service")

DB_URL = cfg.get_db_url()
JWT_SECRET = cfg.get_jwt_secret()
JWT_ALG = "HS256"

# Initialize recommendation engine
engine = rec_engine_module.RecommendationEngine(DB_URL)


class RecommendationRequest(BaseModel):
    user_role: Optional[str] = None
    user_id: Optional[int] = None
    department: Optional[str] = None
    classroom: Optional[str] = None


def decode_token(authorization: Optional[str] = Header(None)) -> dict:
    """Decode JWT token from Authorization header."""
    if not authorization:
        raise HTTPException(status_code=401, detail="Authorization header required")
    
    try:
        # Remove 'Bearer ' prefix if present
        token = authorization.replace("Bearer ", "")
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALG])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")


@app.get("/recommendations")
def get_recommendations(authorization: Optional[str] = Header(None)):
    """
    Get personalized recommendations based on user context from JWT token.
    
    Automatically extracts user role, department, and other context from the JWT.
    Returns prioritized list of actionable recommendations.
    """
    # Decode token to get user context
    try:
        user_context = decode_token(authorization)
    except HTTPException:
        # If no valid token, return generic recommendations
        return {
            "recommendations": [
                {
                    "id": "login_required",
                    "title": "Login Required",
                    "message": "Please login to view personalized recommendations",
                    "type": "informational",
                    "priority": "info",
                    "icon": "login",
                }
            ],
            "count": 1,
        }
    
    # Extract user information
    role = user_context.get("role", "student")
    user_id = user_context.get("sub")
    department = user_context.get("department")
    classroom = user_context.get("ktu_id")  # For class reps, this is their classroom ID
    
    # Get recommendations from engine
    try:
        recommendations = engine.get_recommendations(
            user_role=role,
            user_id=user_id,
            department=department,
            classroom=classroom,
        )
        
        return {
            "recommendations": recommendations,
            "count": len(recommendations),
            "user": {
                "role": role,
                "department": department,
            },
        }
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate recommendations: {str(e)}"
        )


@app.post("/recommendations")
def get_recommendations_with_context(
    req: RecommendationRequest,
    authorization: Optional[str] = Header(None)
):
    """
    Get recommendations with explicit context override.
    Useful for testing or when querying on behalf of others.
    """
    # Try to get user context from token, but allow override
    user_context = {}
    try:
        user_context = decode_token(authorization)
    except HTTPException:
        pass
    
    # Use provided values or fall back to token values
    role = req.user_role or user_context.get("role", "student")
    user_id = req.user_id or user_context.get("sub")
    department = req.department or user_context.get("department")
    classroom = req.classroom or user_context.get("ktu_id")
    
    try:
        recommendations = engine.get_recommendations(
            user_role=role,
            user_id=user_id,
            department=department,
            classroom=classroom,
        )
        
        return {
            "recommendations": recommendations,
            "count": len(recommendations),
            "context": {
                "role": role,
                "department": department,
                "classroom": classroom,
            },
        }
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate recommendations: {str(e)}"
        )


@app.get("/recommendations/count")
def get_recommendation_count(authorization: Optional[str] = Header(None)):
    """Get count of recommendations by priority for badge display."""
    try:
        user_context = decode_token(authorization)
    except HTTPException:
        return {"total": 0, "critical": 0, "high": 0, "medium": 0, "low": 0}
    
    role = user_context.get("role", "student")
    user_id = user_context.get("sub")
    department = user_context.get("department")
    classroom = user_context.get("ktu_id")
    
    try:
        recommendations = engine.get_recommendations(
            user_role=role,
            user_id=user_id,
            department=department,
            classroom=classroom,
        )
        
        counts = {"total": len(recommendations), "critical": 0, "high": 0, "medium": 0, "low": 0, "info": 0}
        for rec in recommendations:
            priority = rec.get("priority", "info")
            if priority in counts:
                counts[priority] += 1
        
        return counts
    except Exception:
        return {"total": 0, "critical": 0, "high": 0, "medium": 0, "low": 0}


@app.get("/health")
def health():
    return {"status": "ok", "service": "recommendations"}
