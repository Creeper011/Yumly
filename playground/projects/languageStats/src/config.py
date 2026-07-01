"""Loads and validates the analyzer's Yumly configuration."""

from dataclasses import dataclass
from pathlib import Path
from typing import Any
from yumly import Yumly
from .languages import BUILTIN_LANGUAGES, Language


DEFAULT_IGNORED_DIRECTORIES = frozenset(
    {
        ".git",
        ".venv",
        "__pycache__",
        "build",
        "dist",
        "node_modules",
        "target",
    }
)


@dataclass(frozen=True)
class ScanConfig:
    languages: tuple[Language, ...]
    ignored_directories: frozenset[str]
    ignored_files: tuple[str, ...]
    include_hidden: bool
    percentage_decimal_places: int


def _strings(value: Any, field: str) -> tuple[str, ...]:
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise ValueError(f"'{field}' must be a list of strings")
    return tuple(value)


def _custom_languages(raw_customs: Any) -> tuple[Language, ...]:
    if not isinstance(raw_customs, list):
        raise ValueError("'customs' must be a list")

    customs: list[Language] = []
    for index, raw in enumerate(raw_customs):
        if not isinstance(raw, dict):
            raise ValueError(f"customs[{index}] must be an object")

        name = raw.get("name")
        if not isinstance(name, str) or not name.strip():
            raise ValueError(f"customs[{index}].name must be a non-empty string")

        extensions = tuple(
            extension.lower()
            if extension.startswith(".")
            else f".{extension.lower()}"
            for extension in _strings(raw.get("extensions"), "extensions")
        )
        if not extensions:
            raise ValueError(f"customs[{index}].extensions cannot be empty")

        customs.append(Language(name.strip(), extensions))

    return tuple(customs)


class LoadConfig:
    def __init__(self, path: Path):
        self.path = path

    def load(self) -> ScanConfig:
        raw = Yumly().load(self.path)
        scan = raw.get("scan", {})
        if not isinstance(scan, dict):
            raise ValueError("'scan' must be a block")

        ignored_directories = _strings(
            scan.get("ignored-directories", []), "ignored-directories"
        )
        ignored_files = _strings(scan.get("ignored-files", []), "ignored-files")
        include_hidden = scan.get("include-hidden", True)
        decimal_places = scan.get("percentage-decimal-places", 2)

        if not isinstance(include_hidden, bool):
            raise ValueError("'include-hidden' must be a bool")

        if not isinstance(decimal_places, int) or isinstance(decimal_places, bool):
            raise ValueError("'percentage-decimal-places' must be an int")

        if not 0 <= decimal_places <= 6:
            raise ValueError("'percentage-decimal-places' must be between 0 and 6")

        return ScanConfig(
            languages=_custom_languages(raw.get("customs", []))
            + BUILTIN_LANGUAGES,
            ignored_directories=DEFAULT_IGNORED_DIRECTORIES | frozenset(ignored_directories),
            ignored_files=ignored_files,
            include_hidden=include_hidden,
            percentage_decimal_places=decimal_places,
        )
