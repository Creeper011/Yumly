import unittest
from types import SimpleNamespace
from unittest.mock import patch

from yumly import Yumly, YumlyError


class StructuredPythonErrorTests(unittest.TestCase):
    def test_load_error_exposes_diagnostic_and_convenience_properties(self) -> None:
        native = SimpleNamespace(
            loadYumlyPy=lambda _path, _stage: {
                "diagnostic": {
                    "code": "validator.type-mismatch",
                    "message": "wrong type",
                    "line": 3,
                    "col": 5,
                    "endLine": 3,
                    "endCol": 9,
                },
            }
        )

        with patch("yumly.yumly.libyumly", new=native):
            with self.assertRaises(YumlyError) as raised:
                Yumly().load("config.yumly")

        error = raised.exception
        self.assertEqual(error.diagnostic.message, "wrong type")
        self.assertEqual(error.code, "validator.type-mismatch")
        self.assertEqual((error.line, error.col), (3, 5))
        self.assertEqual((error.end_line, error.end_col), (3, 9))
        self.assertEqual(str(error), "wrong type")

    def test_string_constructor_remains_available_for_bridge_errors(self) -> None:
        error = YumlyError("invalid bridge value")

        self.assertEqual(str(error), "invalid bridge value")
        self.assertIsNone(error.code)
        self.assertEqual(error.diagnostic.message, "invalid bridge value")


if __name__ == "__main__":
    unittest.main()
