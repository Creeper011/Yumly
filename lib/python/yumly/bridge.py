from typing import Any

from .ast import Token, YumNode
from .diagnostic import Diagnostic
from .yumly_error import YumlyError


def _bridge_error(message: str) -> YumlyError:
    return YumlyError(Diagnostic(message=message))


def map_token(raw: dict[str, Any]) -> Token:
    if not isinstance(raw, dict):
        raise _bridge_error("Invalid token structure received from parser.")
    if "kind" not in raw:
        raise _bridge_error("Token is missing 'kind' attribute.")

    return Token(
        kind=raw["kind"],
        line=raw.get("line", 0),
        col=raw.get("col", 0),
        value=raw.get("value"),
        end_line=raw.get("endLine"),
        end_col=raw.get("endCol"),
    )


def map_node(raw: dict[str, Any]) -> YumNode:
    if not isinstance(raw, dict):
        raise _bridge_error("Invalid node structure received from parser.")
    if "kind" not in raw:
        raise _bridge_error("Node is missing 'kind' attribute.")

    return YumNode(
        kind=raw["kind"],
        name=raw.get("name", ""),
        line=raw.get("line", 0),
        col=raw.get("col", 0),
        source_file=raw.get("sourceFile"),
        raw_value=raw.get("rawValue"),
        env_name=raw.get("envName"),
        env_default=raw.get("envDefault"),
        key=raw.get("key"),
        type_hint=raw.get("typeHint"),
        include_path=raw.get("includePath"),
    )
