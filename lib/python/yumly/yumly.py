"""
Yumly is a cute, declarative config language with fail-fast behavior and optional type safety.
Python library for parsing and validating yumly files and content strings.
"""

from enum import Enum
from pathlib import Path
from typing import Any, IO, Literal, Union, overload
try:
    from . import libyumly  # type: ignore
except ImportError:
    libyumly = None  # type: ignore[assignment]

from .ast import Token, YumNode
from .bridge import map_node, map_token
from .diagnostic import Diagnostic
from .yumly_error import YumlyError

__all__ = [
    "Diagnostic",
    "PipelineResult",
    "PipelineStage",
    "Yumly",
    "YumlyError",
    "YumlyData",
]

FALLBACK_MESSAGE = "Oh no.. an unexpected error occurred.. :( the Yumly parser failed"


# NOTE: These values should be in sync with PipelineStage in the native pipeline.
class PipelineStage(Enum):
    Tokenizer = 0
    Parser = 1
    Load_Includes = 2
    Resolver = 3
    Evaluator = 4
    Validator = 5


PipelineResult = Union[list[Token], list[YumNode], "YumlyData"]


def _native():
    if libyumly is None:
        raise RuntimeError("Yumly's core extension is not installed. Build the Python package before using parser or serializer operations.")
    return libyumly

class YumlyData(dict[str, Any]):
    """Dictionary returned by Yumly loaders with its original Yumyumy snapshot."""

    __slots__ = ("_snapshot", "_yumyumy")

    def __init__(self, data: dict[str, Any], yumyumy: str | None = None):
        super().__init__(data)
        self._yumyumy = yumyumy
        self._snapshot = repr(dict(self))

    def original_yumyumy(self) -> str | None:
        # If this value did not come from the native loader, there is no original rendering.
        if self._yumyumy is None:
            return None
        # If the dict changed after load, regenerate instead of reusing the old rendering.
        if repr(dict(self)) != self._snapshot:
            return None
        return self._yumyumy

class Yumly:
    """
    Yumly is a cute, declarative config language with fail-fast behavior and optional type safety.
    Python library for parsing and validating yumly files and content strings.
    """

    def load(self, path: Union[str, Path]) -> YumlyData:
        """Load a Yumly file."""
        return self.load_until(path, PipelineStage.Validator)

    @overload
    def load_until(self, path: Union[str, Path], until: Literal[PipelineStage.Tokenizer]) -> list[Token]: ...

    @overload
    def load_until(self, path: Union[str, Path], until: Literal[PipelineStage.Parser, PipelineStage.Load_Includes, PipelineStage.Resolver]) -> list[YumNode]: ...

    @overload
    def load_until(self, path: Union[str, Path], until: Literal[PipelineStage.Evaluator, PipelineStage.Validator]) -> YumlyData: ...

    @overload
    def load_until(self, path: Union[str, Path], until: PipelineStage) -> PipelineResult: ...

    def load_until(self, path: Union[str, Path], until: PipelineStage) -> PipelineResult:
        """Load a Yumly file up to a specific pipeline stage."""
        return self._parse_file(Path(path), until)

    def loads(self, yumly_data: str, working_dir: str = ".") -> YumlyData:
        """Load Yumly content."""
        return self.loads_until(yumly_data, PipelineStage.Validator, working_dir)

    @overload
    def loads_until(self, yumly_data: str, until: Literal[PipelineStage.Tokenizer], working_dir: str = ".") -> list[Token]: ...

    @overload
    def loads_until(self, yumly_data: str, until: Literal[PipelineStage.Parser, PipelineStage.Load_Includes, PipelineStage.Resolver], working_dir: str = ".") -> list[YumNode]: ...

    @overload
    def loads_until(self, yumly_data: str, until: Literal[PipelineStage.Evaluator, PipelineStage.Validator], working_dir: str = ".") -> YumlyData: ...

    @overload
    def loads_until(self, yumly_data: str, until: PipelineStage, working_dir: str = ".") -> PipelineResult: ...

    def loads_until(self, yumly_data: str, until: PipelineStage, working_dir: str = ".") -> PipelineResult:
        """Load Yumly content up to a specific pipeline stage."""
        return self._parse_content(yumly_data, working_dir, until)

    def to_yumyumy(self, data: dict[str, Any]) -> str:
        """Convert a Yumly dictionary into its internal yumyumy representation"""
        if isinstance(data, YumlyData):
            original = data.original_yumyumy()
            # If the loaded data is unchanged, keep the exact native Yumyumy snapshot.
            if original is not None:
                return original

        try:
            return _native().dictToYumyumyPy(data)
        except Exception as exc:
            raise self._wrap_error(exc) from exc

    def validate_content(self, yumly_data: str, working_dir: str = ".") -> bool:
        """Validate Yumly content"""
        self._parse_content(yumly_data, working_dir)
        return True

    def validate_file(self, path: Union[str, Path]) -> bool:
        """Validate a Yumly file"""
        self._parse_file(Path(path))
        return True

    def dumps(self, data: dict[str, Any]) -> str:
        """Dump data to a Yumly content string."""
        try:
            return _native().dumpPy(data)
        except Exception as exc:
            raise self._wrap_error(exc) from exc

    def dump(self, data: dict[str, Any], stream: IO[str]) -> None:
        """
        Dump data to a Yumly content stream.
        WARNING: dumping serializes the whole document at once.
        """
        try:
            stream.write(_native().dumpPy(data))
        except Exception as exc:
            raise self._wrap_error(exc) from exc

    def _wrap_error(self, exc: Exception) -> YumlyError:
        """Mounts a structured YumlyError with Diagnostics"""
        msg = str(exc).strip() or FALLBACK_MESSAGE
        return YumlyError(Diagnostic(message=msg), cause=exc)

    def _diagnostic_from_raw(self, raw: Any) -> Diagnostic:
        diagnostic = dict(raw)
        return Diagnostic(
            code=diagnostic["code"] or None,
            message=diagnostic["message"] or None,
            line=diagnostic["line"] or None,
            col=diagnostic["col"] or None,
            end_line=diagnostic["endLine"] or None,
            end_col=diagnostic["endCol"] or None,
            source_file=diagnostic.get("sourceFile") or None,
        )

    def _unwrap_result(self, raw: Any) -> Any:
        result = dict(raw)
        # If native returned a diagnostic envelope, expose it as a typed YumlyError.
        if "diagnostic" in result:
            raise YumlyError(self._diagnostic_from_raw(result["diagnostic"]))
        return result["value"]

    def _map_pipeline_result(self, value: Any, until: PipelineStage) -> PipelineResult:
        if until == PipelineStage.Tokenizer:
            return [map_token(token) for token in value]
        if until in (PipelineStage.Parser, PipelineStage.Load_Includes, PipelineStage.Resolver):
            return [map_node(node) for node in value]
        return YumlyData(value["data"], value["yumyumy"])

    def _parse_file(self, path: Path, until: PipelineStage = PipelineStage.Validator) -> PipelineResult:
        try:
            value = self._unwrap_result(_native().loadYumlyPy(str(path.resolve()), until.value))
            return self._map_pipeline_result(value, until)
        except YumlyError:
            raise
        except Exception as exc:
            raise self._wrap_error(exc) from exc

    def _parse_content(self, yumly_data: str, working_dir: str, until: PipelineStage = PipelineStage.Validator) -> PipelineResult:
        try:
            value = self._unwrap_result(_native().loadYumlyContentPy(yumly_data, working_dir, until.value))
            return self._map_pipeline_result(value, until)
        except YumlyError:
            raise
        except Exception as exc:
            raise self._wrap_error(exc) from exc
