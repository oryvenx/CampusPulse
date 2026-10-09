"""
/auth/login and /auth/me
"""

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.services import auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


class LoginRequest(BaseModel):
    username: str = Field(..., min_length=3, examples=["staff1@campuspulse.local"])
    password: str = Field(..., min_length=6)


@router.post("/login")
def login(body: LoginRequest) -> dict:
    """Authenticate against Cognito and return a bearer token."""
    return auth_service.login(body.username, body.password)


@router.get("/me")
def me(user: dict = Depends(auth_service.current_user)) -> dict:
    return {
        "username": user.get("email") or user.get("cognito:username") or user.get("sub"),
        "email": user.get("email"),
        "name": user.get("name"),
        "groups": user.get("cognito:groups") or [],
    }
