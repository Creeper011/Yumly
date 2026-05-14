import os
import pytest
from pathlib import Path
from typing import Any, Dict, List, TypedDict, Union

from yumly import Yumly, YumlyError, PipelineStage, PipelineResult

class CaseDefinition(TypedDict):
    id: str
    folder_path: Path
    case_file: str
    test_name: str
    is_valid_expected: bool
    phase_str: str
    envs: Dict[str, Any]

def get_test_cases() -> List[CaseDefinition]:
    cases: List[CaseDefinition] = []
    fixtures_dir = Path("tests/fixtures")
    
    if not fixtures_dir.is_dir():
        return cases

    for kind in ["valid", "invalid"]:
        kind_path = fixtures_dir / kind
        if not kind_path.is_dir():
            continue

        for folder_name in os.listdir(kind_path):
            folder_path = kind_path / folder_name
            if not folder_path.is_dir():
                continue

            metadata_path = folder_path / "metadata.yumly"
            if not metadata_path.exists():
                continue

            yumly_tmp = Yumly()
            try:
                # metadata.yumly is expected to be a valid yumly file that evaluates to a dict
                meta: Dict[str, Any] = yumly_tmp.load(metadata_path)
            except YumlyError:
                continue
                
            test_name: str = str(meta.get("name", folder_name))
            is_valid_expected: bool = bool(meta.get("valid", True))
            phase_str: str = str(meta.get("phase", "E"))
            test_cases: List[str] = list(meta.get("cases", []))
            envs_block: Dict[str, Any] = dict(meta.get("envs", {}))

            for case_file in test_cases:
                cases.append({
                    "id": f"{folder_name} - {case_file}",
                    "folder_path": folder_path,
                    "case_file": case_file,
                    "test_name": test_name,
                    "is_valid_expected": is_valid_expected,
                    "phase_str": phase_str,
                    "envs": envs_block
                })
    return cases

@pytest.fixture(scope="module")
def yumly() -> Yumly:
    return Yumly()

@pytest.mark.parametrize("test_def", get_test_cases(), ids=lambda t: t["id"])
def test_yumly_phases(yumly: Yumly, test_def: CaseDefinition) -> None:
    # Setup Envs
    env_keys: List[str] = []
    if isinstance(test_def["envs"], dict):
        for k, v in test_def["envs"].items():
            os.environ[k] = str(v)
            env_keys.append(k)

    full_path: Path = test_def["folder_path"] / test_def["case_file"]
    
    phase_map: Dict[str, PipelineStage] = {
        "T": PipelineStage.Tokenizer,
        "P": PipelineStage.Parser,
        "R": PipelineStage.Resolver,
        "LI": PipelineStage.Resolver,
        "V": PipelineStage.Validator,
        "E": PipelineStage.Evaluator,
    }
    
    stage: PipelineStage = phase_map.get(test_def["phase_str"], PipelineStage.Evaluator)
    is_valid_expected: bool = test_def["is_valid_expected"]

    try:
        data: PipelineResult = yumly.load_until(full_path, stage)
        
        if not is_valid_expected:
            pytest.fail("Kyaa~! Expected failure, but it passed! (o_O)")

        if stage == PipelineStage.Evaluator and isinstance(data, dict):
            expected_file = full_path.with_suffix(".expected.yumyumy")
            if expected_file.exists():
                expected_content: str = expected_file.read_text().strip()
                actual_content: str = yumly.to_yumyumy(data).strip()
                
                assert actual_content == expected_content, "Evaluator output doesn't match expected yumyumy format"
                
        if stage == PipelineStage.Tokenizer and isinstance(data, list):
            expected_file = full_path.with_suffix(".expected.tokens")
            if expected_file.exists():
                expected_content: str = expected_file.read_text().strip()
                
                lines: List[str] = []
                for t in data:
                    kind: str = t.kind
                    if kind in {"tkString", "tkIdent", "tkLiteral"}:
                        lines.append(f'{kind} "{t.value}"')
                    else:
                        lines.append(str(kind))
                    if kind == "tkEOF": break
                
                actual_content: str = "\n".join(lines).strip()
                assert actual_content == expected_content, "Tokenizer output doesn't match expected tokens format"
                
    except YumlyError as e:
        if is_valid_expected:
            pytest.fail(f"Expected success, but got YumlyError: {e}")
            
    finally:
        # Teardown Envs
        for key in env_keys:
            if key in os.environ:
                del os.environ[key]
