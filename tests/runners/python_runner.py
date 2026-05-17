import os
import time
import pytest
from pathlib import Path
from typing import Any, Dict, List, TypedDict
from yumly import Yumly, YumlyError, PipelineStage, PipelineResult
from utils_python.memory import get_rss

class CaseDefinition(TypedDict):
    id: str
    folder_path: Path
    case_file: str
    test_name: str
    is_valid_expected: bool
    phase_str: str
    envs: Dict[str, Any]


ALL_STAGES = [
    PipelineStage.Tokenizer,
    PipelineStage.Parser,
    PipelineStage.Resolver,
    PipelineStage.Load_Includes,
    PipelineStage.Validator,
    PipelineStage.Evaluator,
]

PHASE_MAP: Dict[str, PipelineStage] = {
    "T": PipelineStage.Tokenizer,
    "P": PipelineStage.Parser,
    "R": PipelineStage.Resolver,
    "LI": PipelineStage.Load_Includes,
    "V": PipelineStage.Validator,
    "E": PipelineStage.Evaluator,
}


def get_test_cases() -> List[CaseDefinition]:
    cases: List[CaseDefinition] = []
    fixtures_dir = Path("tests/fixtures")

    if not fixtures_dir.is_dir():
        return cases

    for kind in ("valid", "invalid", "stress"):
        kind_path: Path = fixtures_dir / kind
        if not kind_path.is_dir():
            continue

        for folder_name in os.listdir(kind_path):
            folder_path: Path = kind_path / folder_name
            if not folder_path.is_dir():
                continue

            metadata_path: Path = folder_path / "metadata.yumly"
            if not metadata_path.exists():
                continue

            yumly_tmp: Yumly = Yumly()
            try:
                # metadata.yumly must be a valid yumly file that evaluates to a dict
                meta: Dict[str, Any] = yumly_tmp.load(metadata_path)
            except YumlyError:
                continue

            test_name = str(meta.get("name", folder_name))
            is_valid_expected = bool(meta.get("valid", True))
            phase_str = str(meta.get("phase", "E"))
            test_cases = list(meta.get("cases", []))
            envs_block = dict(meta.get("envs", {}))

            for case_file in test_cases:
                cases.append({
                    "id": f"{folder_name} - {case_file}",
                    "folder_path": folder_path,
                    "case_file": case_file,
                    "test_name": test_name,
                    "is_valid_expected": is_valid_expected,
                    "phase_str": phase_str,
                    "envs": envs_block,
                })

    return cases


@pytest.fixture(scope="module")
def yumly() -> Yumly:
    return Yumly()


def _collect_benchmark(yumly: Yumly, full_path: Path, stage: PipelineStage, collector) -> None:
    stages_to_bench = []
    for stage in ALL_STAGES:
        stages_to_bench.append(stage)
        if stage == stage:
            break

    for stage in stages_to_bench:
        mem_before = get_rss()
        time_before = time.perf_counter()

        yumly.load_until(full_path, stage)

        time_after = time.perf_counter()
        mem_after = get_rss()

        collector.add(
            full_path,
            stage.name.lower(),
            time_after - time_before,
            max(0, (mem_after - mem_before) / (1024 * 1024)),
        )


def _assert_evaluator_output(yumly: Yumly, full_path: Path, data: PipelineResult) -> None:
    if not isinstance(data, dict):
        return

    expected_file = full_path.with_suffix(".expected.yumyumy")
    if not expected_file.exists():
        return

    expected_content = expected_file.read_text().strip()
    actual_content = yumly.to_yumyumy(data).strip()

    assert actual_content == expected_content, (
        "Evaluator output doesn't match expected yumyumy format"
    )


def _assert_tokenizer_output(full_path: Path, data: PipelineResult) -> None:
    if not isinstance(data, list):
        return

    expected_file = full_path.with_suffix(".expected.tokens")
    if not expected_file.exists():
        return

    expected_content = expected_file.read_text().strip()

    lines = []
    for token in data:
        kind = token.kind
        if kind in {"tkString", "tkIdent", "tkLiteral"}:
            lines.append(f'{kind} "{token.value}"')
        else:
            lines.append(str(kind))
        if kind == "tkEOF":
            break

    actual_content = "\n".join(lines).strip()
    assert actual_content == expected_content, (
        "Tokenizer output doesn't match expected tokens format"
    )


@pytest.mark.parametrize("test_def", get_test_cases(), ids=lambda t: t["id"])
def test_yumly_phases(yumly: Yumly, test_def: CaseDefinition, benchmark_collector) -> None:
    env_keys = []
    if isinstance(test_def["envs"], dict):
        for k, v in test_def["envs"].items():
            os.environ[k] = str(v)
            env_keys.append(k)

    full_path = test_def["folder_path"] / test_def["case_file"]
    stage = PHASE_MAP.get(test_def["phase_str"], PipelineStage.Evaluator)
    is_valid_expected = test_def["is_valid_expected"]

    try:
        if benchmark_collector.is_enabled:
            _collect_benchmark(yumly, full_path, stage, benchmark_collector)

        data: PipelineResult = yumly.load_until(full_path, stage)

        if not is_valid_expected:
            pytest.fail("Kyaa~! Expected failure, but it passed! (o_O)")

        if stage == PipelineStage.Evaluator:
            _assert_evaluator_output(yumly, full_path, data)

        if stage == PipelineStage.Tokenizer:
            _assert_tokenizer_output(full_path, data)

    except YumlyError as e:
        if is_valid_expected:
            pytest.fail(f"Expected success, but got YumlyError: {e}")

    finally:
        for key in env_keys:
            os.environ.pop(key, None)