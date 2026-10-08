from __future__ import annotations

import boto3
from botocore.exceptions import ClientError

from app.config import settings


if settings.use_local_db:
    from moto import mock_aws
    _moto_mock = mock_aws()
    _moto_mock.start()


def _client():
    return boto3.client("dynamodb", region_name=settings.aws_region)


def _resource():
    return boto3.resource("dynamodb", region_name=settings.aws_region)


def ensure_tables() -> None:
    """Create the two DynamoDB tables if they don't exist yet."""
    client = _client()

    try:
        client.describe_table(TableName=settings.events_table)
    except ClientError as e:
        if e.response["Error"]["Code"] != "ResourceNotFoundException":
            raise
        client.create_table(
            TableName=settings.events_table,
            BillingMode="PAY_PER_REQUEST",
            AttributeDefinitions=[
                {"AttributeName": "event_id", "AttributeType": "S"},
                {"AttributeName": "building", "AttributeType": "S"},
                {"AttributeName": "timestamp", "AttributeType": "S"},
            ],
            KeySchema=[{"AttributeName": "event_id", "KeyType": "HASH"}],
            GlobalSecondaryIndexes=[
                {
                    "IndexName": "by_building_time",
                    "KeySchema": [
                        {"AttributeName": "building", "KeyType": "HASH"},
                        {"AttributeName": "timestamp", "KeyType": "RANGE"},
                    ],
                    "Projection": {"ProjectionType": "ALL"},
                },
            ],
        )
        client.get_waiter("table_exists").wait(TableName=settings.events_table)

    try:
        client.describe_table(TableName=settings.users_table)
    except ClientError as e:
        if e.response["Error"]["Code"] != "ResourceNotFoundException":
            raise
        client.create_table(
            TableName=settings.users_table,
            BillingMode="PAY_PER_REQUEST",
            AttributeDefinitions=[
                {"AttributeName": "username", "AttributeType": "S"},
            ],
            KeySchema=[{"AttributeName": "username", "KeyType": "HASH"}],
        )
        client.get_waiter("table_exists").wait(TableName=settings.users_table)


def events_table():
    return _resource().Table(settings.events_table)


def users_table():
    return _resource().Table(settings.users_table)