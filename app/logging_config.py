"""
Structured JSON logging for FastAPI.

Emits one JSON object per log line to stdout. CloudWatch agent tails
systemd journal → CloudWatch Logs.
"""

import logging
import sys
import uuid
from contextvars import ContextVar

import structlog


# Per-request id, set by middleware
request_id_ctx: ContextVar[str] = ContextVar("request_id", default="")


def configure_logging(level: str = "INFO") -> None:
    """Call once at app startup."""
    timestamper = structlog.processors.TimeStamper(fmt="iso", utc=True)

    shared_processors = [
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.StackInfoRenderer(),
        timestamper,
        _add_request_id,
    ]

    structlog.configure(
        processors=shared_processors + [
            structlog.processors.format_exc_info,
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(
            getattr(logging, level.upper(), logging.INFO)
        ),
        logger_factory=structlog.PrintLoggerFactory(file=sys.stdout),
        cache_logger_on_first_use=True,
    )

    # Also route stdlib loggers (uvicorn, etc.) through structlog-ish format
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=getattr(logging, level.upper(), logging.INFO),
    )


def _add_request_id(logger, method_name, event_dict):
    rid = request_id_ctx.get()
    if rid:
        event_dict["request_id"] = rid
    return event_dict


def get_logger(name: str = "campuspulse"):
    return structlog.get_logger(name)


def new_request_id() -> str:
    return uuid.uuid4().hex[:12]


def set_request_id(rid: str) -> None:
    request_id_ctx.set(rid)