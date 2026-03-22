from pathlib import Path
from typing import Any, Union, IO
from contextlib import contextmanager
from . import libyumly # type: ignore
from .yumly_error import YumlyError

__all__ = ["Yumly", "YumlyError"]

FALLBACK_MESSAGE = "Oh no.. an unexpected error occurred.. :( the Yumly parser failed"
FALLBACK_VALUE_MESSAGE = "Oh no.. an unexpected error occurred.. :( invalid result structure"

class Yumly():
    """Yumly is a configuration file format designed to be a mix of YAML and JSON with type safety."""

    def load(self, path: Union[str, Path]) -> dict[str, Any]:
        """Load data from a yumly file"""
        path_obj = Path(path)
        return self._parse_file(path_obj)
    
    def loads(self, yuml_data: str, working_dir: str = ".") -> dict[str, Any]:
        """Load data from a yumly content string"""
        return self._parse_content(yuml_data, working_dir)
    
    def validate_content(self, yuml_data: str) -> bool:
        """Validate raw yumly content string (this skips the resolving of env vars and includes)"""
        try:
            msg = libyumly.validateContentMsg(yuml_data)
            if msg:
                raise YumlyError(msg)
        except YumlyError:
            raise
        except Exception as exc:
            msg = str(exc).strip() or FALLBACK_MESSAGE
            raise YumlyError(msg) from exc
        
        return True

    def validate_file(self, path: Union[str, Path]) -> bool:
        """Validate a yumly file (this skips the resolving of env vars and includes)"""
        path_str = str(Path(path).resolve())
        try:
            msg = libyumly.validateFileMsg(path_str)
            if msg:
                raise YumlyError(msg)
        except YumlyError:
            raise
        except Exception as exc:
            msg = str(exc).strip() or FALLBACK_MESSAGE
            raise YumlyError(msg) from exc

        return True

    def _parse_file(self, path: Path) -> dict[str, Any]:
        path_str = str(Path(path).resolve())
        try:
            value = libyumly.loadYumlyPy(path_str)
        except Exception as exc:
            msg = str(exc).strip() or FALLBACK_MESSAGE
            raise YumlyError(msg) from exc

        if not isinstance(value, dict):
            raise YumlyError(FALLBACK_VALUE_MESSAGE)

        return value
    
    def _parse_content(self, yuml_data: str, working_dir: str = ".") -> dict[str, Any]:
        try:
            value = libyumly.loadYumlyContentPy(yuml_data, working_dir)
        except Exception as exc:
            msg = str(exc).strip() or FALLBACK_MESSAGE
            raise YumlyError(msg) from exc

        if not isinstance(value, dict):
            raise YumlyError(FALLBACK_VALUE_MESSAGE)

        return value
    
    def dumps(self, data: dict[str, Any]) -> str:
        """Dump data to a yumly content string"""
        try:
            return libyumly.dumpPy(data)
        except Exception as exc:
            raise YumlyError(str(exc) or FALLBACK_MESSAGE) from exc
    
    def dump(self, data: dict[str, Any], stream: IO[str]) -> None:
        """Dump data to a yumly content stream"""
        try:
            stream.write(libyumly.dumpPy(data))
        except Exception as exc:
            raise YumlyError(str(exc) or FALLBACK_MESSAGE) from exc