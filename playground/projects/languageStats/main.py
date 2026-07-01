"""cli"""

import argparse
from pathlib import Path

from src.analyzer import LanguageAnalyzer
from src.config import LoadConfig
from src.report import print_report


def parse_args() -> argparse.Namespace:
    project_directory = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(
        description="Analyze language percentages with an extensible Yumly config."
    )
    parser.add_argument(
        "path",
        nargs="?",
        type=Path,
        default=Path.cwd(),
        help="source tree to scan (default: current directory)",
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=project_directory / "config.yumly",
        help="Yumly configuration file",
    )
    parser.add_argument(
        "--show-unknown",
        action="store_true",
        help="show the breakdown of unrecognized file extensions",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    root = args.path.expanduser().resolve()
    config = LoadConfig(args.config.expanduser().resolve()).load()
    analysis = LanguageAnalyzer(config).scan(root)

    print_report(
        root,
        analysis,
        config.percentage_decimal_places,
        args.show_unknown,
    )


if __name__ == "__main__":
    main()
