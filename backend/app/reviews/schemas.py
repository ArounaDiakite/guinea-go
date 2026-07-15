from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class ReviewTargetType(str, Enum):
    TRIP = "trip"
    HOTEL = "hotel"
    ROOM = "room"
    EVENT = "event"
    PRODUCT = "product"
    STORE = "store"
    COMPANY = "company"


class ReviewCreate(BaseModel):
    target_type: ReviewTargetType
    target_id: str
    rating: int = Field(..., ge=1, le=5)
    comment: Optional[str] = Field(None, max_length=2000)


class ReviewUpdate(BaseModel):
    """target_type/target_id are deliberately not here - they identify
    which thing this review is about, not a mutable attribute of the
    review itself. Changing them would make it a different review, so
    PUT only ever touches rating/comment."""

    rating: int = Field(..., ge=1, le=5)
    comment: Optional[str] = Field(None, max_length=2000)


class ReviewResponse(BaseModel):
    id: str
    author_id: str
    target_type: ReviewTargetType
    target_id: str
    rating: int
    comment: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class ReviewListResponse(BaseModel):
    target_type: ReviewTargetType
    target_id: str
    average_rating: Optional[float] = None
    count: int
    reviews: list[ReviewResponse]
