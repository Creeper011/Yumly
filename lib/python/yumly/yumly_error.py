"""Module for custom exceptions in Yumly."""

from .diagnostic import Diagnostic


class YumlyError(Exception):
    """Base class for exceptions in this module."""

    def __init__(self, diagnostic: Diagnostic | str, *, cause: Exception | None = None):
        if isinstance(diagnostic, str):
            diagnostic = Diagnostic(message=diagnostic)

        self.diagnostic = diagnostic
        self.message = diagnostic.message or "Yumly parser failed"
        self.cause = cause
        super().__init__(self.message)

    @property
    def code(self) -> str | None:
        return self.diagnostic.code

    @property
    def line(self) -> int | None:
        return self.diagnostic.line

    @property
    def col(self) -> int | None:
        return self.diagnostic.col

    @property
    def end_line(self) -> int | None:
        return self.diagnostic.end_line

    @property
    def end_col(self) -> int | None:
        return self.diagnostic.end_col
