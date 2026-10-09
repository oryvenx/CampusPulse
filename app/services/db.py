"""
DynamoDB client + table accessors.
"""

from __future__ import annotations

import boto3
from boto3.resources.base import ServiceResource

from app.config import settings


_resource: ServiceResource | None = None


def _get_resource() -> ServiceResource:
    """Lazily create and cache the DynamoDB resource (per process)."""
    global _resource
    if _resource is None:
        _resource = boto3.resource("dynamodb", region_name=settings.aws_region)
    return _resource


def events_table():
    return _get_resource().Table(settings.events_table)


def users_table():
    return _get_resource().Table(settings.users_table)
