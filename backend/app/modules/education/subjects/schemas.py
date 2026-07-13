from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class SubjectCreate(BaseModel):
    institution_id: str
    name: str = Field(..., min_length=1, max_length=100)


class SubjectResponse(BaseModel):
    id: str
    institution_id: str
    name: str
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
