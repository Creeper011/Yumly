import os
import shlex
import subprocess
import sys
from pathlib import Path
from setuptools import setup # type: ignore
from setuptools.command.build_py import build_py # type: ignore

bdist_wheel = None  # type: ignore[assignment]

try:
    from wheel.bdist_wheel import bdist_wheel as _bdist_wheel  # type: ignore[assignment]

    class bdist_wheel(_bdist_wheel):
        """Force the wheel to be tagged as platform-specific but Python-version agnostic."""
        def run(self):
            self.run_command("build_py")
            _bdist_wheel.run(self)

        def finalize_options(self):
            _bdist_wheel.finalize_options(self)
            self.root_is_pure = False

        def get_tag(self):
            python, abi, plat = _bdist_wheel.get_tag(self)
            return ("py3", "none", plat)
except ImportError:
    pass

NIM_SOURCE_PATH = Path("src/Yumly/libyumly.nim")
MODULE_NAME = "libyumly"
PACKAGE_NAME = "yumly"


def _extension_suffix() -> str:
    return ".pyd" if sys.platform.startswith("win") else ".so"

class BuildNim(build_py):
    """Custom build command to compile Nim code."""

    def run(self):
        output_dir = Path(self.build_lib) / PACKAGE_NAME
        output_dir.mkdir(parents=True, exist_ok=True)

        output_path = output_dir / f"{MODULE_NAME}{_extension_suffix()}"
        nimcache_path = Path("build/nimcache")
        nimcache_path.mkdir(parents=True, exist_ok=True)

        nimflags = shlex.split(os.environ.get("NIMFLAGS", ""))

        if sys.platform.startswith("win") and not any(flag.startswith("--cc:") for flag in nimflags):
            nimflags.insert(0, "--cc:vcc")

        command = [
            "nim", "c",
            *nimflags,
            "-d:release",
            "-d:python",
            "--app:lib",
            "--lineTrace:off",
            "--debuginfo:off",
            f"--nimcache:{nimcache_path}",
            f"--out:{output_path}",
            str(NIM_SOURCE_PATH),
        ]

        try:
            print("=" * 20)
            print("Compiling Nim code...")
            subprocess.check_call(command)
            print(f"Nim code compiled successfully: {output_path}")
            print("=" * 20)
        except subprocess.CalledProcessError as e:
            print(f"Error compiling Nim code: {e}")
            raise
        except FileNotFoundError:
            print("Error: 'nim' not found. Please ensure Nim is installed and in your PATH.")
            raise

        super().run()


cmdclass = {"build_py": BuildNim}
if bdist_wheel is not None:
    cmdclass["bdist_wheel"] = bdist_wheel

setup(cmdclass=cmdclass, zip_safe=False)