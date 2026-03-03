from pathlib import Path
from typing import Any, Union
from . import libyumly # type: ignore
from .yumly_error import YumlyError

__all__ = ["Yumly", "YumlyError"]

FALLBACK_MESSAGE = "Oh no.. an unexpected error occurred.. :( the Yumly parser failed"
FALLBACK_VALUE_MESSAGE = "Oh no.. an unexpected error occurred.. :( invalid result structure"

class Yumly():
    """Yumly is a configuration file format designed to be a mix of YAML and JSON with type safety."""

    def load(self, path: Union[str, Path]) -> dict[str, Any]:
        """Loads all yumly data from a path."""
        path_obj = Path(path)
        config = self._parse(path_obj)
        return config
    
    def validate_content(self, yuml_data: str) -> bool:
        """Validate raw string data"""
        try:
            error_msg: str = libyumly.validateContentMsg(yuml_data)
        except Exception as exc:
            msg = str(exc).strip() or FALLBACK_MESSAGE
            raise YumlyError(msg) from exc
        
        if error_msg:
            raise YumlyError(error_msg)
        
        return True

    def validate_file(self, path: Union[str, Path]) -> bool:
        """Validate data from a file path"""
        path_str = str(Path(path).resolve())
        try:
            error_msg: str = libyumly.validateFileMsg(path_str)
        except Exception as exc:
            msg = str(exc).strip() or FALLBACK_MESSAGE
            raise YumlyError(msg) from exc
        
        if error_msg:
            raise YumlyError(error_msg)

        return True

    def _parse(self, path: Path) -> dict[str, Any]:
        path_str = str(path.resolve())
        try:
            value = libyumly.loadYumlyPy(path_str)
        except Exception as exc:
            msg = str(exc).strip() or FALLBACK_MESSAGE
            raise YumlyError(msg) from exc

        if not isinstance(value, dict):
            raise YumlyError(FALLBACK_VALUE_MESSAGE)

        return value