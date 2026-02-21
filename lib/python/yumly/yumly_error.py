"""Module for custom exceptions in Yumly."""

class YumlyError(Exception):
    """Base class for exceptions in this module."""
    def __init__(self, message: str):
        self.message = message
        super().__init__(self.message)