import typing
import dataclasses
from typing import cast, Type, TypeVar, Any, get_args, get_origin, Union
from . import libyumly # type: ignore
from .yumly_error import YumlyError

T = TypeVar("T")

__all__ = ["Yumly", "YumlyError"]

class Yumly():
    """Yumly is a configuration file format that is designed to be an mix of YAML and JSON with type safaty and a rigorous struct."""

    def __init__(self, path: str):
        self.path = path
        self.config = None

    def load(self) -> dict[str, Any]:
        """Loads all yumly data"""
        self.config = self._parse()
        return self.config
    
    def load_env(self) -> dict[str, Any]:
        """Loads only env yumly data"""
        raise NotImplementedError()
    
    def validate(self, yuml_data: dict[str, Any]) -> None:
        """Validate data"""
        raise NotImplementedError()

    def _parse(self) -> dict[str, Any]:
        try:
            value = libyumly.loadYumlyPy(self.path)
        except Exception as exc:
            msg = str(exc).strip()
            if not msg:
                msg = "Oh no.. an unexpected error ocurred.. :( the Yumly parser failed"
            raise YumlyError(msg) from exc

        if not isinstance(value, dict):
            raise YumlyError("Oh no.. an unexpected error ocurred.. :( invalid config structure")

        return value