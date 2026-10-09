"""
Central configuration.

In production (EC2), values are read from the environment variables set by
the systemd unit. In dev/test, missing secrets are auto-fetched from SSM
Parameter Store using the developer's AWS credentials.
"""

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

    def model_post_init(self, __context) -> None:
        """
        If SENSOR_API_KEY is not provided via env, fetch it from SSM.
        Uses the same path as production, so no code branches on environment.
        Silently no-ops if SSM is unreachable — the sensor path just fails auth.
        """
        if self.sensor_api_key:
            return
        try:
            import boto3

            ssm = boto3.client("ssm", region_name=self.aws_region)
            self.sensor_api_key = ssm.get_parameter(
                Name="/campuspulse/sensor_api_key",
                WithDecryption=True,
            )["Parameter"]["Value"]
        except Exception:
            pass


settings = Settings()
