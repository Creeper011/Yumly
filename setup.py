import shutil
import subprocess
import sys
from pathlib import Path

from setuptools import setup  # type: ignore
from setuptools.command.build_py import build_py  # type: ignore

try:
    from setuptools.command.bdist_wheel import (  # type: ignore[assignment]
        bdist_wheel as _bdist_wheel,
    )
except ImportError:
    try:
        from wheel.bdist_wheel import (  # type: ignore[assignment]
            bdist_wheel as _bdist_wheel,
        )
    except ImportError:
        _bdist_wheel = None  # type: ignore[assignment,misc]

if _bdist_wheel is not None:
    class bdist_wheel(_bdist_wheel):
        """Force the wheel to be tagged as platform-specific but Python-version agnostic."""

        def finalize_options(self):
            _bdist_wheel.finalize_options(self)
            self.root_is_pure = False

        def get_tag(self):
            _, _, plat = _bdist_wheel.get_tag(self)
            return ("py3", "none", plat)

PROJECT_ROOT = Path(__file__).resolve().parent
NIMBLE_DIR = PROJECT_ROOT / "build" / "nimble"
NATIVE_PACKAGE_DIR = PROJECT_ROOT / "build" / "lib" / "python" / "yumly"
MODULE_NAME = "libyumly"
PACKAGE_NAME = "yumly"


def _extension_suffix() -> str:
    return ".pyd" if sys.platform.startswith("win") else ".so"


class BuildPython(build_py):
    """Build the native Python extension through Yumly's Nimble interface."""

    def run(self):
        super().run()

        output_dir = Path(self.build_lib) / PACKAGE_NAME
        output_dir.mkdir(parents=True, exist_ok=True)

        output_path = output_dir / f"{MODULE_NAME}{_extension_suffix()}"
        native_path = NATIVE_PACKAGE_DIR / f"{MODULE_NAME}{_extension_suffix()}"
        command = [
            "nimble",
            f"--nimbleDir:{NIMBLE_DIR}",
            "buildPython",
        ]

        try:
            print("=" * 20)
            print("Building the Python extension through Nimble...")
            subprocess.check_call(command, cwd=PROJECT_ROOT)
        except subprocess.CalledProcessError as e:
            print(f"Error building the Python extension: {e}")
            raise
        except FileNotFoundError:
            print(
                "Error: 'nimble' not found. "
                "Please ensure Nimble is installed and in your PATH."
            )
            raise

        if not native_path.is_file():
            raise RuntimeError(
                f"Nimble did not produce the expected artifact: {native_path}"
            )

        shutil.copy2(native_path, output_path)
        print(f"Python extension copied to: {output_path}")
        print("=" * 20)


cmdclass = {"build_py": BuildPython}
if _bdist_wheel is not None:
    cmdclass["bdist_wheel"] = bdist_wheel

setup(
    cmdclass=cmdclass,
    options={"build": {"build_base": "build/setuptools"}},
    zip_safe=False,
)
