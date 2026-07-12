from fastapi import HTTPException


def validate_image_file(filename: str, content_type: str):
    allowed_extensions = {"jpg", "jpeg", "png", "webp"}
    allowed_content_types = {"image/jpeg", "image/png", "image/webp"}

    extension = filename.split(".")[-1].lower()

    if extension not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail="Only JPG, JPEG, PNG and WEBP images are allowed.",
        )

    if content_type not in allowed_content_types:
        raise HTTPException(
            status_code=400,
            detail="Invalid image type.",
        )

    return extension