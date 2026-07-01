"""Renders language analysis as terminal tables."""

from pathlib import Path

from .analyzer import Analysis, LanguageTotal


def _table(title: str, label: str, totals: dict[str, LanguageTotal], decimal_places: int) -> None:
    total_bytes = sum(total.bytes for total in totals.values())
    label_width = max(len(label), *(len(name) for name in totals))

    print(title)
    print(
        f"{label:<{label_width}}  "
        f"{'Percent':>9}  {'Bytes':>12}  {'Files':>7}"
    )
    print(f"{'-' * label_width}  {'-' * 9}  {'-' * 12}  {'-' * 7}")

    ordered = sorted(totals.items(), key=lambda item: (-item[1].bytes, item[0]))
    for name, total in ordered:
        percentage = 100 * total.bytes / total_bytes if total_bytes else 0.0
        print(
            f"{name:<{label_width}}  "
            f"{percentage:>{8}.{decimal_places}f}%  "
            f"{total.bytes:>12,}  "
            f"{total.files:>7}"
        )


def print_report(root: Path, analysis: Analysis, decimal_places: int, show_unknown: bool) -> None:
    print(f"Language distribution for {root}")
    print()
    _table("", "Language", analysis.recognized, decimal_places)

    recognized_bytes = sum(total.bytes for total in analysis.recognized.values())
    recognized_files = sum(total.files for total in analysis.recognized.values())
    unknown_bytes = sum(total.bytes for total in analysis.unknown.values())
    unknown_files = sum(total.files for total in analysis.unknown.values())

    print()
    print(f"Recognized: {recognized_bytes:,} bytes in {recognized_files} files")
    print(f"Unknown:    {unknown_bytes:,} bytes in {unknown_files} files")

    if show_unknown and analysis.unknown:
        print()
        _table("Unknown extensions", "Extension", analysis.unknown, decimal_places)
