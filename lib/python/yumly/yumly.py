"""
Yumly is a cute, declarative config language with fail-fast behavior and optional type safety.
Python Library for parsing and validating yumly files and content strings.
"""

from enum import Enum
from pathlib import Path
from typing import Any, Union, IO, overload, Literal
from . import libyumly  # type: ignore
from .yumly_error import YumlyError
from .ast import Token, YumNode
from .bridge import map_token, map_node

__all__ = ["Yumly", "YumlyError", "PipelineStage", "PipelineResult"]

FALLBACK_MESSAGE = "Oh no.. an unexpected error occurred.. :( the Yumly parser failed"
FALLBACK_VALUE_MESSAGE = (
    "Oh no.. an unexpected error occurred.. :( invalid result structure"
)

class PipelineStage(Enum):
    Tokenizer = 0
    Parser = 1
    Load_Includes = 2
    Resolver = 3
    Validator = 4
    Evaluator = 5

PipelineResult = Union[list[Token], YumNode, dict[str, Any]]

class YumlyData(dict[str, Any]):
    __slots__ = ("_snapshot", "_yumyumy")

    def __init__(self, data: dict[str, Any], yumyumy: str | None = None):
        super().__init__(data)
        self._yumyumy = yumyumy
        self._snapshot = repr(dict(self))

    def original_yumyumy(self) -> str | None:
        if self._yumyumy is None:
            return None
        if repr(dict(self)) != self._snapshot:
            return None
        return self._yumyumy

class Yumly:
    """
    Yumly is a cute, declarative config language with fail-fast behavior and optional type safety.
    Python Library for parsing and validating yumly files and content strings.
    """

    def load(self, path: Union[str, Path]) -> dict[str, Any]:
        """Load data from a yumly file"""
        path_obj = Path(path)
        return self._parse_file(path_obj, PipelineStage.Evaluator)

    @overload
    def load_until(self, path: Union[str, Path], until: Literal[PipelineStage.Tokenizer]) -> list[Token]: ...
    
    @overload
    def load_until(self, path: Union[str, Path], until: Literal[PipelineStage.Parser, PipelineStage.Load_Includes, PipelineStage.Resolver, PipelineStage.Validator]) -> YumNode: ...
    
    @overload
    def load_until(self, path: Union[str, Path], until: Literal[PipelineStage.Evaluator]) -> dict[str, Any]: ...
    
    @overload
    def load_until(self, path: Union[str, Path], until: PipelineStage) -> PipelineResult: ...

    def load_until(self, path: Union[str, Path], until: PipelineStage) -> PipelineResult:
        """Load data from a yumly file up to a specific pipeline stage"""
        path_obj = Path(path)
        return self._parse_file(path_obj, until)

    def loads(self, yumly_data: str, working_dir: str = ".") -> dict[str, Any]:
        """Load data from a yumly content string"""
        return self._parse_content(yumly_data, working_dir, PipelineStage.Evaluator)

    @overload
    def loads_until(self, yumly_data: str, until: Literal[PipelineStage.Tokenizer], working_dir: str = ".") -> list[Token]: ...

    @overload
    def loads_until(self, yumly_data: str, until: Literal[PipelineStage.Parser, PipelineStage.Load_Includes, PipelineStage.Resolver, PipelineStage.Validator], working_dir: str = ".") -> YumNode: ...

    @overload
    def loads_until(self, yumly_data: str, until: Literal[PipelineStage.Evaluator], working_dir: str = ".") -> dict[str, Any]: ...
    
    @overload
    def loads_until(self, yumly_data: str, until: PipelineStage, working_dir: str = ".") -> PipelineResult: ...

    def loads_until(self, yumly_data: str, until: PipelineStage, working_dir: str = ".") -> PipelineResult:
        """Load data from a yumly content string up to a specific pipeline stage"""
        return self._parse_content(yumly_data, working_dir, until)

    def to_yumyumy(self, data: dict[str, Any]) -> str:
        """Convert a Yumly dictionary into its internal yumyumy representation"""
        if isinstance(data, YumlyData):
            original = data.original_yumyumy()
            if original is not None:
                return original

        try:
            return libyumly.dictToYumyumyPy(data)
        except Exception as exc:
            raise YumlyError(str(exc) or FALLBACK_MESSAGE) from exc

    def validate_content(self, yumly_data: str) -> bool:
        """Validate raw yumly content string (this skips the resolving of env vars and includes)"""
        try:
            msg = libyumly.validateContentMsg(yumly_data)
            if msg:
                raise YumlyError(msg)
        except YumlyError:
            raise
        except Exception as exc:
            msg = str(exc).strip() or FALLBACK_MESSAGE
            raise YumlyError(msg) from exc

        return True

    def validate_file(self, path: Union[str, Path]) -> bool:
        """Validate a yumly file (this skips the resolving of env vars and includes)"""
        path_str = str(Path(path).resolve())
        try:
            msg = libyumly.validateFileMsg(path_str)
            if msg:
                raise YumlyError(msg)
        except YumlyError:
            raise
        except Exception as exc:
            msg = str(exc).strip() or FALLBACK_MESSAGE
            raise YumlyError(msg) from exc

        return True

    def _wrap_error(self, exc: Exception) -> YumlyError:
        msg = str(exc).strip() or FALLBACK_MESSAGE
        return YumlyError(msg)

    def _parse_file(self, path: Path, until: PipelineStage) -> PipelineResult:
        path_str = str(Path(path).resolve())
        try:
            if until == PipelineStage.Evaluator:
                bundle = libyumly.loadYumlyEvaluatorPy(path_str)
                return YumlyData(bundle["data"], bundle["yumyumy"])

            value = libyumly.loadYumlyPy(path_str, until.value)
        except Exception as exc:
            raise self._wrap_error(exc) from exc

        if value is None:
            raise YumlyError(FALLBACK_VALUE_MESSAGE)

        if until == PipelineStage.Tokenizer:
            return [map_token(t) for t in value]
        elif until in (PipelineStage.Parser, PipelineStage.Load_Includes, PipelineStage.Resolver, PipelineStage.Validator):
            return map_node(value)  # type: ignore
        return value

    def _parse_content(self, yumly_data: str, working_dir: str, until: PipelineStage) -> PipelineResult:
        try:
            if until == PipelineStage.Evaluator:
                bundle = libyumly.loadYumlyContentEvaluatorPy(yumly_data, working_dir)
                return YumlyData(bundle["data"], bundle["yumyumy"])

            value = libyumly.loadYumlyContentPy(yumly_data, working_dir, until.value)
        except Exception as exc:
            raise self._wrap_error(exc) from exc

        if value is None:
            raise YumlyError(FALLBACK_VALUE_MESSAGE)

        if until == PipelineStage.Tokenizer:
            return [map_token(t) for t in value]
        elif until in (PipelineStage.Parser, PipelineStage.Load_Includes, PipelineStage.Resolver, PipelineStage.Validator):
            return map_node(value)  # type: ignore
        return value

    def dumps(self, data: dict[str, Any]) -> str:
        """Dump data to a yumly content string"""
        try:
            return libyumly.dumpPy(data)
        except Exception as exc:
            raise self._wrap_error(exc) from exc

    def dump(self, data: dict[str, Any], stream: IO[str]) -> None:
        """
        Dump data to a yumly content stream
        WARNING: Yumly by design/archquiteture does not support streaming, so we have to dump the whole content at once.
        """
        try:
            stream.write(libyumly.dumpPy(data))
        except Exception as exc:
            raise self._wrap_error(exc) from exc
