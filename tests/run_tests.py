"""
Quick runner for the Yumly integration tests used in CI and local development.
"""

from __future__ import annotations

import os
import sys
import time
from dataclasses import dataclass, field
from enum import Enum, auto
from pathlib import Path
from typing import Callable, List, Optional

sys.path.insert(0, os.path.abspath("lib/python"))

try:
    from yumly import Yumly, YumlyError
except ImportError as exc:
    print(f"Import failed: {exc}")
    print("Ensure libyumly is built in lib/python/yumly/")
    sys.exit(1)


# ---------------------------------------------------------------------------
# Test primitives
# ---------------------------------------------------------------------------

class Status(Enum):
    PASS = auto()
    FAIL = auto()
    ERROR = auto()


@dataclass
class TestCase:
    name: str
    run: Callable[[], None]
    suite: str = "general"


@dataclass
class TestResult:
    name: str
    suite: str
    status: Status
    duration_ms: float
    message: str = ""


# ---------------------------------------------------------------------------
# Test registry
# ---------------------------------------------------------------------------

_registry: List[TestCase] = []

def test(suite: str = "general"):
    def decorator(fn: Callable):
        _registry.append(TestCase(name=fn.__name__, run=fn, suite=suite))
        return fn
    return decorator


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

BASE = Path("tests/files")
yumly = Yumly()

def env_context(**kwargs):
    """Temporarily set environment variables for a test block."""
    original = {k: os.environ.get(k) for k in kwargs}
    os.environ.update(kwargs)
    try:
        yield
    finally:
        for k, v in original.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v

from contextlib import contextmanager
env_context = contextmanager(env_context)

def assert_loads(path: Path) -> dict:
    return yumly.load(path)

def assert_fails(path: Path, contains: Optional[str] = None):
    try:
        yumly.load(path)
        raise AssertionError(f"Expected YumlyError but load succeeded: {path}")
    except YumlyError as e:
        if contains and contains not in str(e):
            raise AssertionError(
                f"Error message did not contain '{contains}'.\nGot: {e}"
            )

def assert_equal(actual, expected, label: str = ""):
    if actual != expected:
        raise AssertionError(
            f"Assertion failed{' for ' + label if label else ''}.\n"
            f"  Expected: {expected!r}\n"
            f"  Got:      {actual!r}"
        )


# ---------------------------------------------------------------------------
# Valid file tests — syntax
# ---------------------------------------------------------------------------

@test(suite="syntax")
def test_minimal():
    data = assert_loads(BASE / "valid/syntax/minimal.yumly")
    assert_equal(data["app"]["name"], "Yumly", "app.name")
    assert_equal(data["app"]["version"], "0.0.1", "app.version")
    assert_equal(data["app"]["debug"], True, "app.debug")

@test(suite="syntax")
def test_blocks():
    data = assert_loads(BASE / "valid/syntax/blocks.yumly")
    assert "block" in data
    assert "sub-block" in data["block"]

@test(suite="syntax")
def test_key_values():
    data = assert_loads(BASE / "valid/syntax/key_values.yumly")
    assert_equal(data["variable"], "Hello World!")

@test(suite="syntax")
def test_commas():
    data = assert_loads(BASE / "valid/syntax/commas.yumly")
    assert_equal(data["name"], "John Doe")
    assert_equal(data["age"], 180)

@test(suite="syntax")
def test_comments():
    # Comments-only file should produce an empty config without raising
    data = assert_loads(BASE / "valid/syntax/comments.yumly")
    assert isinstance(data, dict)

@test(suite="syntax")
def test_string_escapes():
    data = assert_loads(BASE / "valid/syntax/string_escapes.yumly")
    assert "\n" in data["test_escapes"]["valid_newline"]
    assert "\t" in data["test_escapes"]["valid_tab"]
    assert "\\" in data["test_escapes"]["valid_backslash"]
    assert '"' in data["test_escapes"]["valid_quote"]

@test(suite="syntax")
def test_strings():
    data = assert_loads(BASE / "valid/syntax/strings.yumly")
    assert_equal(data["variable"], "Hello World")
    assert_equal(data["variable2"], "Hello World,\nbut's a multiline string")
    assert_equal(data["variable3"], "Hello world in a multiline string,\nbut with \t scape sequences \t, \n new lines and \""" quotes")
    assert_equal(data["variable4"], "\tHello")

# ---------------------------------------------------------------------------
# Valid file tests — types
# ---------------------------------------------------------------------------

@test(suite="types")
def test_primitives():
    data = assert_loads(BASE / "valid/types/primitives.yumly")
    assert_equal(data["isAdmin"], True)
    assert_equal(data["age"], 20)
    assert_equal(data["price"], 40.6)
    assert_equal(data["name"], "Wow!")
    assert_equal(data["flag"], True)
    assert_equal(data["count"], 40)

@test(suite="types")
def test_lists():
    data = assert_loads(BASE / "valid/types/lists.yumly")
    assert_equal(data["myList"], ["one", "two", "three", "four"])
    assert_equal(data["myList2"], ["one", "two", "three", "four"])

@test(suite="types")
def test_tuples():
    data = assert_loads(BASE / "valid/types/tuples.yumly")
    assert_equal(data["myTuple"], [1, "two", "three", 4])

@test(suite="types")
def test_env_vars():
    with env_context(HOME="/test/home"):
        data = assert_loads(BASE / "valid/types/env_vars.yumly")
        assert_equal(data["home"], "/test/home")
        assert_equal(data["home2"], "/test/home")


@test(suite="types")
def test_symbol_refs_other_symbol():
    assert_loads(BASE / "valid/types/symbol_refs_other_symbol.yumly")


# ---------------------------------------------------------------------------
# Valid file tests — includes
# ---------------------------------------------------------------------------

@test(suite="includes")
def test_include_yuy_and_env():
    data = assert_loads(BASE / "valid/includes/main.yumly")
    assert "block" in data
    assert_equal(data["block"]["variable"], "Hello")
    assert_equal(data["hello"], "Hello")


# ---------------------------------------------------------------------------
# Valid file tests — full configs
# ---------------------------------------------------------------------------

@test(suite="full")
def test_service_stack():
    data = assert_loads(BASE / "valid/full/service_stack.yumly")
    assert_equal(data["global"]["stack_name"], "orion-prod")
    assert_equal(data["global"]["maintenance_mode"], False)
    assert "api_gateway" in data["services"]
    assert "worker" in data["services"]
    assert "cron" in data["services"]

@test(suite="full")
def test_deployment_plan():
    data = assert_loads(BASE / "valid/full/deployment_plan.yuy")
    assert_equal(data["common"]["company"], "Yumly Corp")
    assert_equal(data["common"]["company_string"], "Yumly Corp")
    assert "Yumly Corp is a company" in data["common"]["description"]
    assert_equal(data["credentials"]["db_user"], "app_user")
    assert_equal(data["credentials"]["db_password"], "secret")
    assert_equal(data["credentials"]["jwt_secret"], "supersecretjwt")
    assert_equal(data["plan"]["environment"], "staging")
    assert "canary" in data["plan"]
    assert "traffic" in data["plan"]


# ---------------------------------------------------------------------------
# Invalid file tests
# ---------------------------------------------------------------------------

@test(suite="invalid")
def test_missing_brace_final():
    assert_fails(BASE / "invalid/brace/missing_brace_final.yumly")

@test(suite="invalid")
def test_missing_brace_start():
    assert_fails(BASE / "invalid/brace/missing_brace_start.yumly")

@test(suite="invalid")
def test_unclosed_string():
    assert_fails(BASE / "invalid/unclosed_string.yumly", contains="doesn't close")

@test(suite="invalid")
def test_unclosed_comment():
    assert_fails(BASE / "invalid/unclosed_comment.yumly", contains="doesn't close")

@test(suite="invalid")
def test_bad_string_escape():
    assert_fails(BASE / "invalid/bad_string_escape.yumly", contains="invalid escape")

@test(suite="invalid")
def test_env_only_with_dollar():
    assert_fails(BASE / "invalid/env_only_with_dollar.yumly")

@test(suite="invalid")
def test_heterogeneous_list():
    assert_fails(BASE / "invalid/lists/heterogenius_list.yumly", contains="wrong type")

@test(suite="invalid")
def test_list_with_no_type():
    assert_fails(BASE / "invalid/lists/list_with_no_type.yumly")

@test(suite="invalid")
def test_malformed_list():
    assert_fails(BASE / "invalid/lists/malformed_list.yumly")

@test(suite="invalid")
def test_no_comma_list():
    assert_fails(BASE / "invalid/lists/no_comma_list.yumly")

@test(suite="invalid")
def test_circular_include():
    assert_fails(BASE / "invalid/semantic/circular_include.yumly", contains="Circular")

@test(suite="invalid")
def test_duplicate_symbol():
    assert_fails(BASE / "invalid/semantic/duplicate_symbol.yumly", contains="duplicated")

def test_unknown_symbol():
    assert_fails(BASE / "invalid/semantic/unknown_symbol.yumly", contains="unknown symbol")

def test_circular_symbol():
    assert_fails(BASE / "invalid/semantic/circular_symbol.yumly", contains="circular")

@test(suite="invalid")
def test_unexpected_token():
    assert_fails(BASE / "invalid/unexpected/unexpected_token.yumly")

@test(suite="invalid")
def test_unexpected_token_root():
    assert_fails(BASE / "invalid/unexpected/unexpected_token_root.yumly")


# ---------------------------------------------------------------------------
# API surface tests
# ---------------------------------------------------------------------------

@test(suite="api")
def test_loads_from_string():
    content = '(app) { name = "Yumly", version ;string = "1.0.0" }'
    data = yumly.loads(content)
    assert_equal(data["app"]["name"], "Yumly")
    assert_equal(data["app"]["version"], "1.0.0")

@test(suite="api")
def test_validate_content_valid():
    result = yumly.validate_content('(app) { name = "test" }')
    assert_equal(result, True)

@test(suite="api")
def test_validate_content_invalid():
    try:
        yumly.validate_content('(app) {')
        raise AssertionError("Expected YumlyError")
    except YumlyError:
        pass

@test(suite="api")
def test_validate_file_valid():
    result = yumly.validate_file(BASE / "valid/syntax/minimal.yumly")
    assert_equal(result, True)

@test(suite="api")
def test_validate_file_invalid():
    try:
        yumly.validate_file(BASE / "invalid/brace/missing_brace_final.yumly")
        raise AssertionError("Expected YumlyError")
    except YumlyError:
        pass

@test(suite="api")
def test_dumps_roundtrip():
    original = {
        "name": "Yumly",
        "version": "1.0.0",
        "active": True,
        "port": 8080,
    }
    serialized = yumly.dumps(original)
    assert isinstance(serialized, str)
    assert len(serialized) > 0
    reloaded = yumly.loads(serialized)
    assert_equal(reloaded["name"], "Yumly")
    assert_equal(reloaded["version"], "1.0.0")
    assert_equal(reloaded["active"], True)
    assert_equal(reloaded["port"], 8080)

@test(suite="api")
def test_dump_to_stream():
    import io
    data = {"project": "test", "debug": False}
    stream = io.StringIO()
    yumly.dump(data, stream)
    content = stream.getvalue()
    assert len(content) > 0
    reloaded = yumly.loads(content)
    assert_equal(reloaded["project"], "test")


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

class Colors:
    def __init__(self):
        disabled = os.getenv("NO_COLOR") is not None or not sys.stdout.isatty()
        self.green  = "" if disabled else "\033[32m"
        self.red    = "" if disabled else "\033[31m"
        self.yellow = "" if disabled else "\033[33m"
        self.cyan   = "" if disabled else "\033[36m"
        self.dim    = "" if disabled else "\033[2m"
        self.reset  = "" if disabled else "\033[0m"

    def wrap(self, text: str, color: str) -> str:
        return f"{getattr(self, color)}{text}{self.reset}"


def run_all(suites: Optional[List[str]] = None) -> List[TestResult]:
    results = []
    cases = _registry if not suites else [t for t in _registry if t.suite in suites]

    for case in cases:
        start = time.perf_counter()
        try:
            case.run()
            duration = (time.perf_counter() - start) * 1000
            results.append(TestResult(case.name, case.suite, Status.PASS, duration))
        except AssertionError as e:
            duration = (time.perf_counter() - start) * 1000
            results.append(TestResult(case.name, case.suite, Status.FAIL, duration, str(e)))
        except Exception as e:
            duration = (time.perf_counter() - start) * 1000
            results.append(TestResult(case.name, case.suite, Status.ERROR, duration, str(e)))

    return results


def render(results: List[TestResult]) -> int:
    colors = Colors()
    exit_code = 0

    suites: dict[str, List[TestResult]] = {}
    for r in results:
        suites.setdefault(r.suite, []).append(r)

    for suite_name, suite_results in suites.items():
        print(f"\n{colors.wrap(suite_name.upper(), 'cyan')}")
        print("─" * 60)
        for r in suite_results:
            if r.status == Status.PASS:
                marker = colors.wrap("✔", "green")
            elif r.status == Status.FAIL:
                marker = colors.wrap("✘", "red")
                exit_code = 1
            else:
                marker = colors.wrap("!", "yellow")
                exit_code = 1

            duration = colors.wrap(f"{r.duration_ms:.1f}ms", "dim")
            print(f"  {marker} {r.name} {duration}")
            if r.message:
                for line in r.message.splitlines():
                    print(f"      {colors.wrap(line, 'dim')}")

    total   = len(results)
    passed  = sum(1 for r in results if r.status == Status.PASS)
    failed  = sum(1 for r in results if r.status != Status.PASS)
    total_ms = sum(r.duration_ms for r in results)

    print(f"\n{'─' * 60}")
    summary = f"{passed}/{total} passed"
    print(
        colors.wrap(summary, "green") if failed == 0 else colors.wrap(summary, "red"),
        colors.wrap(f"({total_ms:.0f}ms total)", "dim")
    )

    return exit_code


if __name__ == "__main__":
    requested_suites = sys.argv[1:] or None
    sys.exit(render(run_all(requested_suites)))
