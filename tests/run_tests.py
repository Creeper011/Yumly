"""
Quick runner for the Yumly fixtures used in CI and local development.
"""

from __future__ import annotations

import os
import sys
from dataclasses import dataclass
from enum import Enum, auto
from pathlib import Path
from typing import Iterable, List

sys.path.insert(0, os.path.abspath("lib/python"))

try:
    from yumly import Yumly, YumlyError # type: ignore
except ImportError as exc:
    print(f"Error importing yumly: {exc}")
    print("Make sure libyumly is built in lib/python/yumly/")
    sys.exit(1)


# ---------- Constants ----------
BASE_PATH: Path = Path("tests/files")
EXTENSIONS: tuple[str, ...] = (".yumly", ".yuy")


class Status(Enum):
    OK = auto()
    EXPECTED = auto()
    SHOULD_HAVE_FAILED = auto()
    ERROR = auto()
    CRASH = auto()


@dataclass
class TestResult:
    path: Path
    status: Status
    message: str = ""


class Colors:
    def __init__(self) -> None:
        disable = os.getenv("NO_COLOR") is not None or not sys.stdout.isatty()
        self.red = self.green = self.yellow = self.cyan = self.reset = ""
        if not disable:
            self.red = "\033[31m"
            self.green = "\033[32m"
            self.yellow = "\033[33m"
            self.cyan = "\033[36m"
            self.reset = "\033[0m"

    def wrap(self, text: str, color: str) -> str:
        code = getattr(self, color)
        return f"{code}{text}{self.reset}" if code else text


def iter_fixtures(base: Path) -> Iterable[Path]:
    return sorted(
        candidate
        for candidate in base.rglob("*")
        if candidate.is_file() and candidate.suffix in EXTENSIONS
    )


def classify(path: Path) -> bool:
    """Return True if this file is expected to fail."""
    text = str(path)
    return "invalid" in text or "unexpected" in text


def run_tests() -> List[TestResult]:
    yumly = Yumly()
    results: List[TestResult] = []

    for path in iter_fixtures(BASE_PATH):
        expected_fail = classify(path)
        try:
            yumly.load(path)
            if expected_fail:
                results.append(TestResult(path, Status.SHOULD_HAVE_FAILED, "Marked invalid/unexpected but loaded successfully"))
            else:
                results.append(TestResult(path, Status.OK))
        except YumlyError as err:
            msg = str(err)
            if expected_fail:
                results.append(TestResult(path, Status.EXPECTED, msg))
            else:
                results.append(TestResult(path, Status.ERROR, msg))
        except Exception as err:  # pragma: no cover - defensive
            results.append(TestResult(path, Status.CRASH, str(err)))

    return results


def render(results: List[TestResult]) -> int:
    colors = Colors()
    status_width = 10

    print(f"{'STATUS':<{status_width}} | FILE")
    print("-" * 70)

    exit_code = 0
    for res in results:
        rel = res.path.relative_to(BASE_PATH)
        status_text = {
            Status.OK: colors.wrap("✅ OK", "green"),
            Status.EXPECTED: colors.wrap("🟡 EXPECTED", "yellow"),
            Status.SHOULD_HAVE_FAILED: colors.wrap("❌ SHOULD_HAVE_FAILED", "red"),
            Status.ERROR: colors.wrap("❌ ERROR", "red"),
            Status.CRASH: colors.wrap("💥 CRASH", "red"),
        }[res.status]

        if res.status in {Status.SHOULD_HAVE_FAILED, Status.ERROR, Status.CRASH}:
            exit_code = 1

        msg = f" ({res.message})" if res.message else ""
        print(f"{status_text:<{status_width}} | {rel}{msg}")

    counts = {status: 0 for status in Status} # type: ignore
    for result in results:
        counts[result.status] += 1
    summary = " / ".join(f"{status.name}:{counts[status]}" for status in Status) # type: ignore
    print("-" * 70)
    print(f"Summary: {summary}")
    if exit_code != 0:
        print(colors.wrap("Errors detected.", "red"))
    return exit_code


if __name__ == "__main__":
    if not BASE_PATH.exists():
        print("Error: 'tests/files' directory not found.")
        sys.exit(1)

    sys.exit(render(run_tests()))
