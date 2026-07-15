from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    MONGODB_URL: str
    DATABASE_NAME: str

    SECRET_KEY: str
    ALGORITHM: str
    ACCESS_TOKEN_EXPIRE_MINUTES: int

    # How long a booking stays PENDING_PAYMENT before it's treated as
    # abandoned and its seat is released. float (not int) so tests can
    # override it to a few seconds via the env var of the same name.
    BOOKING_PAYMENT_TIMEOUT_MINUTES: float = 10.0

    # Comma-separated allowed origins for CORS - the Flutter web build
    # runs on its own origin (a dev server port, later a real domain)
    # and needs this to call the API from a browser at all; without it
    # every request from web is blocked before it even reaches a route.
    # "*" (wide open) is fine while nothing is deployed yet - tighten
    # to the real web app's origin(s) before going to production.
    CORS_ORIGINS: str = "*"

    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore"
    )


settings = Settings()