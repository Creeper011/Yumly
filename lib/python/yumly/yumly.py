from . import yumly_core # type: ignore
from .yumly_error import YumlyError

__all__ = ["Yumly", "YumlyError"]

class Yumly():
    """Yumly is a configuration file format that is designed to be an mix of YAML and JSON with type safaty and a rigorous struct."""

    def __init__(self, path: str):
        self.path = path
        self.config = None

    def load(self):
        self.config = self._parse()
        return self.config

    def _parse(self) -> dict:
        try:
            value = yumly_core.parsePyConfig(self.path)
        except Exception as exc:
            msg = str(exc).strip()
            if not msg:
                msg = "Oh no.. an unexpected error ocurred.. :( the Yumly parser failed"
            raise YumlyError(msg) from exc

        if not isinstance(value, dict):
            raise YumlyError("Oh no.. an unexpected error ocurred.. :( invalid config structure")

        return value