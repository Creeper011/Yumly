import subprocess
import sys
from pathlib import Path
from setuptools import setup # type: ignore
from setuptools.command.build_py import build_py # type: ignore

NIM_SOURCE_PATH = "src/Yumly/libyumly.nim"
MODULE_NAME = "libyumly"

def _extension_suffix() -> str:
    platform = sys.platform
    if platform.startswith("win"):
        return ".pyd"
    return ".so"

SHARED_LIB_PATH = Path("lib/python/yumly") / f"{MODULE_NAME}{_extension_suffix()}"

class BuildNim(build_py):
    """Custom build command to compile Nim code."""
    def run(self):
        
        output_path = SHARED_LIB_PATH
        output_path.parent.mkdir(parents=True, exist_ok=True)
        nimcache_path = Path("build/nimcache")
        nimcache_path.mkdir(parents=True, exist_ok=True)
        command = [
            "nim", "c", "-d:release", "--app:lib",
            f"--nimcache:{nimcache_path}",
            f"--out:{output_path}",
            NIM_SOURCE_PATH
        ]
        try:
            print("="*20)
            print("Compiling Nim code...")
            print(f"Running command: {' '.join(command)}")
            subprocess.check_call(command)
            print("Nim code compiled successfully.")
            print("="*20)
        except subprocess.CalledProcessError as e:
            print(f"Error compiling Nim code: {e}")
            raise
        except FileNotFoundError:
            print("Error: 'nim' command not found. Please ensure Nim is installed and in your PATH.")
            raise
        super().run()

setup(
    cmdclass={
        'build_py': BuildNim,
    },
    zip_safe=False,
)
