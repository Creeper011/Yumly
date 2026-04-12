"""
Yumly integration tests
"""

from __future__ import annotations

import io
import sys
from pathlib import Path
from typing import Optional

import pytest

sys.path.insert(0, "lib/python")

from yumly import Yumly, YumlyError

BASE  = Path("tests/files")
YUMLY = Yumly()


def assert_fails(path: Path, contains: Optional[str] = None):
    with pytest.raises(YumlyError) as exc_info:
        YUMLY.load(path)
    if contains:
        assert contains in str(exc_info.value), (
            f"Error message did not contain '{contains}'.\nGot: {exc_info.value}"
        )


# ---------------------------------------------------------------------------
# Syntax
# ---------------------------------------------------------------------------


class TestSyntax:
    def test_minimal(self):
        data = YUMLY.load(BASE / "valid/syntax/minimal.yumly")
        assert data["app"]["name"] == "Yumly"
        assert data["app"]["version"] == "0.0.1"
        assert data["app"]["debug"] is True

    def test_blocks(self):
        data = YUMLY.load(BASE / "valid/syntax/blocks.yumly")
        assert "block" in data
        assert "sub-block" in data["block"]

    def test_key_values(self):
        data = YUMLY.load(BASE / "valid/syntax/key_values.yumly")
        assert data["variable"] == "Hello World!"

    def test_commas(self):
        data = YUMLY.load(BASE / "valid/syntax/commas.yumly")
        assert data["name"] == "John Doe"
        assert data["age"] == 180

    def test_comments(self):
        data = YUMLY.load(BASE / "valid/syntax/comments.yumly")
        assert isinstance(data, dict)

    def test_string_escapes(self):
        data = YUMLY.load(BASE / "valid/syntax/string_escapes.yumly")
        assert "\n" in data["test_escapes"]["valid_newline"]
        assert "\t" in data["test_escapes"]["valid_tab"]
        assert "\\" in data["test_escapes"]["valid_backslash"]
        assert '"' in data["test_escapes"]["valid_quote"]

    def test_strings(self):
        data = YUMLY.load(BASE / "valid/syntax/strings.yumly")
        assert data["variable"] == "Hello World"
        assert data["variable2"] == "Hello World,\nbut's a multiline string"
        assert data["variable3"] == (
            'Hello world in a multiline string,\n'
            'but with \t scape sequences \t, \n new lines and " quotes'
        )
        assert data["variable4"] == "\tHello"


# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------


class TestTypes:
    def test_primitives(self):
        data = YUMLY.load(BASE / "valid/types/primitives.yumly")
        assert data["isAdmin"] is True
        assert data["age"] == 20
        assert data["price"] == 40.6
        assert data["name"] == "Wow!"
        assert data["flag"] is True
        assert data["count"] == 40

    def test_lists(self):
        data = YUMLY.load(BASE / "valid/types/lists.yumly")
        assert data["myList"] == ["one", "two", "three", "four"]
        assert data["myList2"] == ["one", "two", "three", "four"]

    def test_tuples(self):
        data = YUMLY.load(BASE / "valid/types/tuples.yumly")
        assert data["myTuple"] == [1, "two", "three", 4]

    def test_env_vars(self, monkeypatch: pytest.MonkeyPatch):
        monkeypatch.setenv("HOME", "/test/home")
        data = YUMLY.load(BASE / "valid/types/env_vars.yumly")
        assert data["home"] == "/test/home"
        assert data["home2"] == "/test/home"

# ---------------------------------------------------------------------------
# Includes
# ---------------------------------------------------------------------------


class TestIncludes:
    def test_include_yuy_and_env(self):
        data = YUMLY.load(BASE / "valid/includes/main.yumly")
        assert "block" in data
        assert data["block"]["variable"] == "Hello"
        assert data["hello"] == "Hello"


# ---------------------------------------------------------------------------
# Full configs
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Invalid files
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("rel_path,contains", [
    ("brace/missing_brace_final.yumly",        None),
    ("brace/missing_brace_start.yumly",        None),
    ("unclosed_string.yumly",                  "doesn't close"),
    ("unclosed_comment.yumly",                 "doesn't close"),
    ("bad_string_escape.yumly",                "invalid escape"),
    ("env_only_with_dollar.yumly",             None),
    ("lists/heterogenius_list.yumly",          "wrong type"),
    ("lists/list_with_no_type.yumly",          None),
    ("lists/malformed_list.yumly",             None),
    ("lists/no_comma_list.yumly",              None),
    ("semantic/circular_include.yumly",        "Circular"),
    ("unexpected/unexpected_token.yumly",      None),
    ("unexpected/unexpected_token_root.yumly", None),
])
def test_invalid_files(rel_path: str, contains: Optional[str]):
    assert_fails(BASE / "invalid" / rel_path, contains)


# ---------------------------------------------------------------------------
# API surface
# ---------------------------------------------------------------------------


class TestAPI:
    def test_loads_from_string(self):
        content = '(app) { name = "Yumly", version ;string = "1.0.0" }'
        data = YUMLY.loads(content)
        assert data["app"]["name"] == "Yumly"
        assert data["app"]["version"] == "1.0.0"

    def test_validate_content_valid(self):
        assert YUMLY.validate_content('(app) { name = "test" }') is True

    def test_validate_content_invalid(self):
        with pytest.raises(YumlyError):
            YUMLY.validate_content("(app) {")

    def test_validate_file_valid(self):
        assert YUMLY.validate_file(BASE / "valid/syntax/minimal.yumly") is True

    def test_validate_file_invalid(self):
        with pytest.raises(YumlyError):
            YUMLY.validate_file(BASE / "invalid/brace/missing_brace_final.yumly")

    def test_dumps_roundtrip(self):
        original = {"name": "Yumly", "version": "1.0.0", "active": True, "port": 8080}
        serialized = YUMLY.dumps(original)
        assert isinstance(serialized, str) and len(serialized) > 0
        reloaded = YUMLY.loads(serialized)
        assert reloaded["name"] == "Yumly"
        assert reloaded["version"] == "1.0.0"
        assert reloaded["active"] is True
        assert reloaded["port"] == 8080

    def test_dump_to_stream(self):
        data = {"project": "test", "debug": False}
        stream = io.StringIO()
        YUMLY.dump(data, stream)
        content = stream.getvalue()
        assert len(content) > 0
        reloaded = YUMLY.loads(content)
        assert reloaded["project"] == "test"
