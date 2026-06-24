import os
import sys
import time
import pytest
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Dict, List, TypedDict, Optional

sys.path.insert(0, str(Path(__file__).parent.parent))

from yumly import Yumly, YumlyError

BENCHMARK_PREFIX = "YUM_BENCHMARK\t"


def _run_python_sandboxed(code: str, work_dir: Path, timeout: int = 30) -> None:
    python_bin = sys.executable
    if not python_bin:
        pytest.skip("No Python interpreter available")

    with tempfile.TemporaryDirectory(prefix="py_sandbox_") as sandbox_dir:
        env = os.environ.copy()
        for key in list(env.keys()):
            if key in ("PATH", "HOME", "USER", "TMPDIR", "TEMP", "TMP"):
                continue
            del env[key]

        script = (
            "import os, sys\n"
            f"os.chdir({str(work_dir.resolve())!r})\n"
            "sys.path.insert(0, os.getcwd())\n"
            + code
        )

        result = subprocess.run(
            [python_bin, "-c", script],
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=sandbox_dir,
            env=env,
        )
        if result.returncode != 0:
            pytest.fail(
                f"Python pre-suite script failed (exit code {result.returncode}):\n"
                f"{result.stderr or result.stdout}"
            )

class CaseDefinition(TypedDict):
    case_id: str
    folder_path: Path
    case_file: str
    test_name: str
    is_valid_expected: bool
    envs: Dict[str, Any]
    pre_suite_eval: Optional[str]
    expected_code: str


def get_test_cases(kinds: tuple[str, ...]) -> List[CaseDefinition]:
    """
    Scan the tests/fixtures directory and return a list of test cases.
    
    scans metadata.yumly files to populate the test cases.
    if a metadata.yumly file is not found, the folder is skipped.
    """
    cases: List[CaseDefinition] = []
    fixtures_dir = Path("tests/fixtures")

    if not fixtures_dir.is_dir():
        return cases

    for kind in kinds:
        kind_path: Path = fixtures_dir / kind
        if not kind_path.is_dir():
            raise RuntimeError(f"Fixture category does not exist: {kind_path}")

        for folder_name in sorted(os.listdir(kind_path)):
            folder_path: Path = kind_path / folder_name
            if not folder_path.is_dir():
                continue

            metadata_path: Path = folder_path / "metadata.yumly"
            if not metadata_path.exists():
                raise RuntimeError(f"Missing fixture metadata: {metadata_path}")

            yumly_tmp: Yumly = Yumly()
            try:
                meta: Dict[str, Any] = yumly_tmp.load(metadata_path)
            except YumlyError as error:
                raise RuntimeError(
                    f"Invalid fixture metadata {metadata_path}: {error}"
                ) from error

            required = {"name", "valid", "number", "cases"}
            missing = sorted(required.difference(meta))
            if missing:
                raise RuntimeError(
                    f"{metadata_path} is missing required fields: "
                    f"{', '.join(missing)}"
                )

            test_name = str(meta["name"])
            is_valid_expected = bool(meta["valid"])
            test_cases = list(meta["cases"])
            if not test_cases:
                raise RuntimeError(
                    f"{metadata_path} must declare at least one case"
                )
            envs_block = dict(meta.get("envs", {}))
            pre_suite_eval = meta.get("preSuiteEval")
            expected_code = meta.get("expectedCode")

            if not is_valid_expected and not expected_code:
                raise RuntimeError(
                    f"{metadata_path} requires expectedCode"
                )

            for case_file in test_cases:
                case_file = str(case_file)
                full_path = folder_path / case_file
                if not full_path.is_file():
                    raise RuntimeError(
                        f"Fixture case does not exist: {full_path}"
                    )

                cases.append({
                    "case_id": f"{folder_name} - {case_file}",
                    "folder_path": folder_path,
                    "case_file": case_file,
                    "test_name": test_name,
                    "is_valid_expected": is_valid_expected,
                    "envs": envs_block,
                    "pre_suite_eval": pre_suite_eval,
                    "expected_code": str(expected_code or ""),
                })

    return cases


def pytest_generate_tests(metafunc) -> None:
    if "test_def" not in metafunc.fixturenames:
        return

    if metafunc.config.getoption("--stress-only"):
        kinds = ("stress",)
    elif metafunc.config.getoption("--benchmark"):
        kinds = ("valid", "invalid", "stress")
    else:
        kinds = ("valid", "invalid")
    cases = get_test_cases(kinds)
    if not cases:
        raise RuntimeError(f"No fixture cases discovered for {kinds}")
    metafunc.parametrize(
        "test_def",
        cases,
        ids=[case["case_id"] for case in cases],
    )

# fixture to create an global yumly instance
@pytest.fixture(scope="module")
def yumly() -> Yumly:
    return Yumly()


def _parse_benchmark_output(output: str) -> tuple[float, float]:
    for line in output.splitlines():
        if not line.startswith(BENCHMARK_PREFIX):
            continue
        _, duration, memory_delta = line.split("\t")
        return float(duration), float(memory_delta)

    raise RuntimeError(f"Benchmark worker did not report memory/time data:\n{output}")


def _collect_benchmark(
    yumly: Yumly,
    test_id: str,
    full_path: Path,
    expect_failure: bool,
    collector,
) -> None:
    del yumly, expect_failure

    worker = r"""
import sys
import time
from pathlib import Path

repo_root = Path.cwd()
sys.path.insert(0, str(repo_root / "lib" / "python"))
sys.path.insert(0, str(repo_root / "tests" / "runners"))

from yumly import Yumly
from utils_python.memory import get_rss

path = Path(sys.argv[1])
yumly = Yumly()
baseline_memory = get_rss()
time_before = time.perf_counter()

try:
    data = yumly.load(path)
except Exception:
    data = None

duration = time.perf_counter() - time_before
memory_delta = max(0, (get_rss() - baseline_memory) / (1024 * 1024))
del data

print(f"YUM_BENCHMARK\t{duration:.9f}\t{memory_delta:.6f}")
"""

    result = subprocess.run(
        [sys.executable, "-c", worker, str(full_path)],
        capture_output=True,
        text=True,
        cwd=Path.cwd(),
        env=os.environ.copy(),
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"Benchmark worker failed (exit code {result.returncode}):\n"
            f"{result.stderr or result.stdout}"
        )

    duration, memory_delta = _parse_benchmark_output(result.stdout)
    collector.add(
        category="fixture",
        test_id=test_id,
        file_path=full_path,
        operation="pipeline",
        duration=duration,
        memory_delta=memory_delta,
    )


def _assert_evaluator_output(yumly: Yumly, full_path: Path, data: Any) -> None:
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


def test_yumly_fixtures(yumly: Yumly, test_def: CaseDefinition, benchmark_collector) -> None:
    # Execute pre-suite script in a sandboxed Python subprocess
    if test_def["pre_suite_eval"]:
        _run_python_sandboxed(test_def["pre_suite_eval"], test_def["folder_path"])

    previous_env: dict[str, Optional[str]] = {}
    # set env vars for the test
    if isinstance(test_def["envs"], dict):
        for key, value in test_def["envs"].items():
            previous_env[key] = os.environ.get(key)
            os.environ[key] = str(value)

    full_path = test_def["folder_path"] / test_def["case_file"]
    is_valid_expected = test_def["is_valid_expected"]

    try:
        if benchmark_collector.is_enabled:
            _collect_benchmark(
                yumly,
                test_def["case_id"],
                full_path,
                not is_valid_expected,
                benchmark_collector,
            )

        if not is_valid_expected:
            try:
                yumly.load(full_path)
            except YumlyError as error:
                assert error.code == test_def["expected_code"], (
                    f"Expected code {test_def['expected_code']!r}, "
                    f"got {error.code!r}: {error}"
                )
            else:
                pytest.fail("Expected failure, but the case passed")
            return

        data = yumly.load(full_path)
        _assert_evaluator_output(yumly, full_path, data)

    except YumlyError as error:
        pytest.fail(f"Expected success, but got YumlyError: {error}")

    finally:
        for key, previous_value in previous_env.items():
            if previous_value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = previous_value
