import unittest
import os
from yumly import Yumly
from yumly import YumlyError

class TestYumly(unittest.TestCase):
    def setUp(self):
        # Create a dummy example.yumly file for testing
        self.example_file_path = "example.yumly"
        with open(self.example_file_path, "w") as f:
            f.write("""
(global) {
    project_name ;string = "Project Orion",
    version ;string = "2.4.5-stable",
    is_production ;bool = false
}
""")
    
    def tearDown(self):
        # Clean up the dummy file after tests
        if os.path.exists(self.example_file_path):
            os.remove(self.example_file_path)

    def test_validate_file_success(self):
        yumly_parser = Yumly()
        result = yumly_parser.validate_file(self.example_file_path)
        self.assertTrue(result, "Validation failed for a valid yumly file")

    def test_validate_file_failure(self):
        # Create an invalid yumly file for this test
        invalid_file_path = "invalid.yumly"
        with open(invalid_file_path, "w") as f:
            f.write("(invalid {") # Malformed content
        
        yumly_parser = Yumly()
        with self.assertRaisesRegex(YumlyError, r"Heyy i expected '\)', but found '\{' at line 1, column 10\."):
            yumly_parser.validate_file(invalid_file_path)
        
        os.remove(invalid_file_path)


if __name__ == '__main__':
    unittest.main()
