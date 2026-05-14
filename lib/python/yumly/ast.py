from dataclasses import dataclass
from typing import Optional, List

@dataclass(frozen=True)
class Token:
    kind: str
    line: int
    col: int
    value: Optional[str] = None

@dataclass(frozen=True)
class YumNode:
    kind: str
    name: str
    line: int
    col: int
    source_file: Optional[str] = None
    
    # Specific fields based on kind
    raw_value: Optional[str] = None
    key: Optional[str] = None
    type_hint: Optional[str] = None
    val_node: Optional['YumNode'] = None
    include_path: Optional[str] = None
    
    # Config specific
    has_includes: Optional[bool] = None
    has_type_hints: Optional[bool] = None
    has_env_vars: Optional[bool] = None
    
    children: Optional[List['YumNode']] = None
