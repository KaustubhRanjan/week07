import logging
import os
import time
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Response, status
from sqlalchemy import text
from sqlalchemy.exc import OperationalError, SQLAlchemyError
from sqlalchemy.orm import Session

from app.db import Base, engine, get_db
from app.routers import courses


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)

logger = logging.getLogger(__name__)


# Blue/green deployment metadata (SIT722 Task 10.3HD).
# APP_VERSION is baked into the image at build time (the Git commit SHA),
# so it moves with the container when the staging and production slots swap.
# SLOT_NAME is a slot-sticky App Service setting, so it always reports
# which slot is answering ("staging" or "production").
APP_VERSION = os.getenv("APP_VERSION", "local")
SLOT_NAME = os.getenv("SLOT_NAME", "local")


def initialise_database() -> None:
    maximum_attempts = 10
    retry_delay_seconds = 5

    for attempt in range(1, maximum_attempts + 1):
        try:
            Base.metadata.create_all(bind=engine)

            logger.info(
                "Database connection established successfully."
            )

            return

        except OperationalError:
            logger.warning(
                "Database connection failed. Attempt %s of %s.",
                attempt,
                maximum_attempts,
            )

            if attempt == maximum_attempts:
                logger.exception(
                    "Unable to connect to the database."
                )
                raise

            time.sleep(retry_delay_seconds)


@asynccontextmanager
async def lifespan(_: FastAPI):
    initialise_database()
    yield


app = FastAPI(
    title="KoalaTech University Course Service",
    description=(
        "Manages courses and lecturer assignments "
        "for KoalaTech University."
    ),
    version="1.0.0",
    lifespan=lifespan,
)


app.include_router(courses.router)


@app.get("/", tags=["Health"])
def root() -> dict[str, str]:
    return {
        "message": (
            "KoalaTech University Course Service is running."
        )
    }


@app.get("/health", tags=["Health"])
def health_check(
    response: Response,
    db: Session = Depends(get_db),
) -> dict[str, str]:
    """Readiness check used by App Service, the slot-swap warm-up
    and the pipeline smoke tests. Returns 503 if the database is
    unreachable so a broken release is never swapped into production."""
    try:
        db.execute(text("SELECT 1"))
        database_status = "ok"
    except SQLAlchemyError:
        logger.exception("Health check could not reach the database.")
        database_status = "unavailable"
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE

    return {
        "status": (
            "healthy" if database_status == "ok" else "unhealthy"
        ),
        "service": "course-service",
        "version": APP_VERSION,
        "slot": SLOT_NAME,
        "database": database_status,
    }
