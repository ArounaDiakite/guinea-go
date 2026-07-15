from fastapi import APIRouter, Depends

from app.core.dependencies import get_current_user
from app.reviews.schemas import (
    ReviewCreate,
    ReviewListResponse,
    ReviewResponse,
    ReviewTargetType,
    ReviewUpdate,
)
from app.reviews.service import ReviewService

router = APIRouter(
    prefix="/reviews",
    tags=["Reviews"],
)

service = ReviewService()


@router.post("/", response_model=ReviewResponse)
async def create_review(
    data: ReviewCreate,
    current_user=Depends(get_current_user),
):
    return await service.create_review(data, current_user["sub"])


@router.get("/", response_model=ReviewListResponse)
async def get_reviews(target_type: ReviewTargetType, target_id: str):
    return await service.get_reviews(target_type.value, target_id)


@router.get("/{review_id}", response_model=ReviewResponse)
async def get_review(review_id: str):
    return await service.get_review(review_id)


@router.put("/{review_id}", response_model=ReviewResponse)
async def update_review(
    review_id: str,
    data: ReviewUpdate,
    current_user=Depends(get_current_user),
):
    return await service.update_review(review_id, data, current_user["sub"])


@router.delete("/{review_id}")
async def delete_review(
    review_id: str,
    current_user=Depends(get_current_user),
):
    return await service.delete_review(review_id, current_user["sub"])
