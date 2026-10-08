"""
Authentication service — Amazon Cognito.
"""

from __future__ import annotations

import time
from typing import Any, Optional

import boto3
import httpx
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from app.config import settings


bearer_scheme = HTTPBearer(auto_error=False)


def _cognito_client():
    return boto3.client("cognito-idp", region_name=settings.cognito_region)


def login(username: str, password: str) -> dict:
    """Authenticate against Cognito and return tokens + role."""
    client = _cognito_client()
    try:
        resp = client.initiate_auth(
            ClientId=settings.cognito_client_id,
            AuthFlow="USER_PASSWORD_AUTH",
            AuthParameters={"USERNAME": username, "PASSWORD": password},
        )
    except client.exceptions.NotAuthorizedException:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )
    except client.exceptions.UserNotFoundException:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Cognito error: {e}")

    auth = resp["AuthenticationResult"]

    # Decode IdToken (not verify — we just minted it) to read groups + name
    claims = jwt.get_unverified_claims(auth["IdToken"])
    groups = claims.get("cognito:groups") or []

    return {
        "access_token": auth["AccessToken"],
        "id_token": auth["IdToken"],
        "refresh_token": auth.get("RefreshToken"),
        "token_type": "bearer",
        "expires_in": auth["ExpiresIn"],
        "role": groups[0] if groups else None,
        "groups": groups,
        "name": claims.get("name", username),
    }


_JWKS_CACHE: dict[str, Any] = {"keys": None, "fetched_at": 0.0}
_JWKS_TTL_SECONDS = 3600


def _issuer() -> str:
    return (
        f"https://cognito-idp.{settings.cognito_region}.amazonaws.com/"
        f"{settings.cognito_user_pool_id}"
    )


def _jwks_url() -> str:
    return f"{_issuer()}/.well-known/jwks.json"


def _get_jwks() -> dict:
    now = time.time()
    if (
        _JWKS_CACHE["keys"] is None
        or now - _JWKS_CACHE["fetched_at"] > _JWKS_TTL_SECONDS
    ):
        with httpx.Client(timeout=5.0) as c:
            r = c.get(_jwks_url())
            r.raise_for_status()
            _JWKS_CACHE["keys"] = r.json()
            _JWKS_CACHE["fetched_at"] = now
    return _JWKS_CACHE["keys"]


def verify_token(token: str) -> dict:
    """Verify a Cognito access or id token."""
    try:
        return jwt.decode(
            token,
            _get_jwks(),
            algorithms=["RS256"],
            audience=settings.cognito_client_id,
            issuer=_issuer(),
            options={"verify_aud": True},
        )
    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {e}",
            headers={"WWW-Authenticate": "Bearer"},
        )


def current_user(
    creds: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
) -> dict:
    """Require a valid bearer token; return decoded claims."""
    if creds is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return verify_token(creds.credentials)


def require_role(*allowed_roles: str):
    """Dependency factory: only allow users whose cognito:groups intersect allowed_roles."""
    def _checker(user: dict = Depends(current_user)) -> dict:
        groups = user.get("cognito:groups") or []
        if not any(r in groups for r in allowed_roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Requires one of roles: {list(allowed_roles)}",
            )
        return user
    return _checker