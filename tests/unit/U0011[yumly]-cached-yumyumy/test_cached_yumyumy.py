import unittest
from types import SimpleNamespace
from unittest.mock import patch

from yumly.yumly import Yumly, YumlyData


class YumlyDataTests(unittest.TestCase):
    def test_returns_cached_yumyumy_while_data_is_unchanged(self) -> None:
        data = YumlyData(
            {"database": {"port": 5432}},
            "[database] (port (int) -> 5432)",
        )

        self.assertEqual(
            data.original_yumyumy(),
            "[database] (port (int) -> 5432)",
        )

    def test_invalidates_cache_after_top_level_or_nested_changes(self) -> None:
        top_level = YumlyData({"name": "Yumly"}, "cached")
        top_level["name"] = "Yumly 2"
        self.assertIsNone(top_level.original_yumyumy())

        nested = YumlyData({"database": {"port": 5432}}, "cached")
        nested["database"]["port"] = 3306
        self.assertIsNone(nested.original_yumyumy())

    def test_to_yumyumy_uses_cache_before_native_serializer(self) -> None:
        data = YumlyData({"name": "Yumly"}, "cached output")

        with patch(
            "yumly.yumly.libyumly",
            new=SimpleNamespace(
                dictToYumyumyPy=lambda _: (_ for _ in ()).throw(
                    AssertionError("native serializer should not run")
                )
            ),
        ):
            self.assertEqual(Yumly().to_yumyumy(data), "cached output")


if __name__ == "__main__":
    unittest.main()
