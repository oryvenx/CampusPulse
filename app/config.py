from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "prod"
    aws_region: str = "eu-west-3"

    events_table: str = "campuspulse-events"
    users_table: str = "campuspulse-users"

    cognito_user_pool_id: str = ""
    cognito_client_id: str = ""
    cognito_region: str = "eu-west-3"

    sensor_api_key: str = ""

    log_group: str = "/campuspulse/api"


settings = Settings()