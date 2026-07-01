"""Diagnostics of the Yumly Python API."""

from dataclasses import asdict, dataclass
from typing import Any

@dataclass(frozen=True)
class Diagnostic:
    code: str | None = None
    message: str | None = None
    line: int | None = None
    col: int | None = None
    end_line: int | None = None
    end_col: int | None = None
    source_file: str | None = None

    def as_dict(self) -> dict[str, Any]:
        """Return a dictionary using Python-style field names."""
        return asdict(self)
