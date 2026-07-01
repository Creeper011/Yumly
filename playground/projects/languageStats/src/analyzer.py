"""Classifies files and measures their byte distribution."""

import fnmatch
import os
import sys
from collections.abc import Iterable
from dataclasses import dataclass, field
from pathlib import Path

from .config import ScanConfig
from .languages import Language


@dataclass
class LanguageTotal:
    bytes: int = 0
    files: int = 0


@dataclass
class Analysis:
    recognized: dict[str, LanguageTotal] = field(default_factory=dict)
    unknown: dict[str, LanguageTotal] = field(default_factory=dict)


def classify(path: Path, languages: Iterable[Language]) -> str | None:
    filename = path.name.lower()
    for language in languages:
        if filename in language.filenames:
            return language.name
        if any(filename.endswith(extension) for extension in language.extensions):
            return language.name
    return None


def _is_ignored_file(relative_path: Path, patterns: tuple[str, ...]) -> bool:
    relative = relative_path.as_posix()
    return any(
        fnmatch.fnmatch(relative, pattern) or fnmatch.fnmatch(relative_path.name, pattern)
        for pattern in patterns
    )


def _unknown_extension(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix:
        return suffix
    if path.name.startswith("."):
        return path.name.lower()
    return "(no extension)"


class LanguageAnalyzer:
    def __init__(self, config: ScanConfig):
        self.config = config

    def scan(self, root: Path) -> Analysis:
        analysis = Analysis()

        for directory, directory_names, filenames in os.walk(root):
            current = Path(directory)
            directory_names[:] = sorted(
                name
                for name in directory_names
                if name not in self.config.ignored_directories
                and (self.config.include_hidden or not name.startswith("."))
                and not (current / name).is_symlink()
            )

            for filename in sorted(filenames):
                if not self.config.include_hidden and filename.startswith("."):
                    continue

                path = current / filename
                relative = path.relative_to(root)
                if path.is_symlink() or _is_ignored_file(
                    relative, self.config.ignored_files
                ):
                    continue

                try:
                    size = path.stat().st_size
                except OSError as error:
                    print(f"warning: could not read {relative}: {error}", file=sys.stderr)
                    continue

                language_name = classify(path, self.config.languages)
                if language_name is None:
                    extension = _unknown_extension(path)
                    total = analysis.unknown.setdefault(extension, LanguageTotal())
                else:
                    total = analysis.recognized.setdefault(
                        language_name, LanguageTotal()
                    )

                total.bytes += size
                total.files += 1

        return analysis
