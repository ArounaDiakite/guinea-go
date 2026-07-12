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

    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore"
    )


settings = Settings()