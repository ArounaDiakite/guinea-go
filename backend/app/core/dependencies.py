from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt

from app.core.config import settings
from app.core.constants import UserRole
from app.core.permissions import role_has_permission

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")


async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired token.",
    )

    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )

        user_id = payload.get("sub")

        if user_id is None:
            raise credentials_exception

        return payload

    except JWTError:
        raise credentials_exception


def require_role(*allowed_roles: UserRole):
    """Dependency factory: restrict a route to specific roles.

    `system_administrator` always passes, per its full-access mandate.
    """

    async def dependency(current_user: dict = Depends(get_current_user)):
        role = current_user.get("role")

        if role == UserRole.SYSTEM_ADMINISTRATOR or role in allowed_roles:
            return current_user

        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have the required role to perform this action.",
        )

    return dependency


def require_permission(permission: str):
    """Dependency factory: restrict a route to a specific permission,
    resolved from the current user's role via ROLE_PERMISSIONS."""

    async def dependency(current_user: dict = Depends(get_current_user)):
        role = current_user.get("role")

        if role_has_permission(role, permission):
            return current_user

        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Missing required permission: {permission}.",
        )

    return dependency