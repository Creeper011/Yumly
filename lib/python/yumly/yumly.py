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
        ...
    
    def validate(self, yuml_data: dict[str, Any]) -> None:
        """Validate data"""
        ...

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
    
    #def _resolve_dataclass_type(self, field_type: Any) -> type | None:
    #    """resolve types for Optional, Union etc"""
    #    if dataclasses.is_dataclass(field_type):
    #        return field_type
    #
    #    if get_origin(field_type) is Union:
    #        for arg in get_args(field_type):
    #            if arg is type(None):
    #                continue
    #            if dataclasses.is_dataclass(arg):
    #                return arg

    #    return None

    #def to_dataclass(self, cls: Type[T], yumly_data: dict[str, Any]) -> T | None:
    #    """Convert an data to a"""
    #    if not dataclasses.is_dataclass(cls):
    #        raise TypeError(f"{cls} is not a dataclass")

    #    hints = typing.get_type_hints(cls)
    #    kwargs: dict[str, Any] = {}

    #    for field in dataclasses.fields(cls):
    #        field_name = field.name
    #        field_type = hints[field_name]

    #        if field_name not in yumly_data:
    #            if field.default is not dataclasses.MISSING:
    #                kwargs[field_name] = field.default
    #            elif field.default_factory is not dataclasses.MISSING:  # type: ignore[misc]
    #                kwargs[field_name] = field.default_factory()
    #            else:
    #                raise ValueError(f"Required field missing: '{field_name}'")
    #            continue

    #        value = yumly_data[field_name]
    #        nested_cls = _resolve_dataclass_type(field_type)

    #        if nested_cls is not None and isinstance(value, dict):
    #            kwargs[field_name] = self.to_dataclass(cast(Type[Any], nested_cls), value)
    #        else:
    #            kwargs[field_name] = value

    #    return cls(**kwargs)