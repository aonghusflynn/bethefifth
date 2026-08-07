from pydantic import BaseModel, Field


class PaginationParams(BaseModel):
    page: int = Field(1, ge=1)
    per_page: int = Field(20, ge=1, le=100)


class ErrorResponse(BaseModel):
    """RFC 7807 problem+json format."""

    type: str = "about:blank"
    title: str
    status: int
    detail: str
    instance: str | None = None
