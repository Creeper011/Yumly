from typing import Any, Optional, List
from .ast import Token, YumNode
from .yumly_error import YumlyError

def map_token(raw: dict[str, Any]) -> Token:
    if not isinstance(raw, dict):
        raise YumlyError("Invalid token structure received from parser.")
    if "kind" not in raw:
        raise YumlyError("Token is missing 'kind' attribute.")
    
    return Token(
        kind=raw["kind"],
        line=raw.get("line", 0),
        col=raw.get("col", 0),
        value=raw.get("value")
    )

def map_node(raw: Optional[dict[str, Any]]) -> Optional[YumNode]:
    if raw is None:
        return None
        
    if not isinstance(raw, dict):
        raise YumlyError("Invalid node structure received from parser.")
    if "kind" not in raw:
        raise YumlyError("Node is missing 'kind' attribute.")
    
    children_raw = raw.get("children", [])
    children = [map_node(c) for c in children_raw if c is not None] if children_raw else None
    
    val_node_raw = raw.get("valNode")
    val_node = map_node(val_node_raw) if val_node_raw else None
    
    return YumNode(
        kind=raw["kind"],
        name=raw.get("name", ""),
        line=raw.get("line", 0),
        col=raw.get("col", 0),
        source_file=raw.get("sourceFile"),
        raw_value=raw.get("rawValue"),
        key=raw.get("key"),
        type_hint=raw.get("typeHint"),
        val_node=val_node,
        include_path=raw.get("includePath"),
        has_includes=raw.get("hasIncludes"),
        has_type_hints=raw.get("hasTypeHints"),
        has_env_vars=raw.get("hasEnvVars"),
        children=children
    )
