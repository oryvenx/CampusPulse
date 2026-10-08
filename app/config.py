from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "dev"
    aws_region: str = "us-east-1"

    events_table: str = "campuspulse-events"
    users_table: str = "campuspulse-users"

    cognito_user_pool_id: str = ""
    cognito_client_id: str = ""

    jwt_secret: str = "change-me-locally"

    use_local_db: bool = True


settings = Settings()