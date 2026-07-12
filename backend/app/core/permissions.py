from fastapi import HTTPException, status


def ensure_owner(resource_owner_id: str, current_user_id: str):
    if resource_owner_id != current_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not allowed to perform this action.",
        )