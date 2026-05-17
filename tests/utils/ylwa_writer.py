"""
A mini library to construct Ylwa files programmatically.
Ylwa is a representative language for benchmarking.
"""

class YlwaWriter:
    def __init__(self):
        self.output = ""

    def add_header(self, header: str):
        """Adds a top-level header (e.g., .> Title <.)"""
        self.output += f".> {header} <.\n\n"

    def add_comment(self, comment: str):
        """Adds a multiline comment block."""
        comment_lines = comment.replace("\n", "\n  ")
        self.output += f".> \n  {comment_lines}\n.< \n\n"

    def begin_block(self, name: str):
        """Starts a block (~ Name :)"""
        self.output += f"~ {name} :\n"

    def add_field(self, name: str, value: str):
        """Adds a field-value pair (- Name ; Value,)"""
        # Values in Ylwa are strings, no specific typing.
        self.output += f"  - {name} ; {value},\n"

    def end_block(self):
        """Ends the current block (:)"""
        self.output += ":\n\n"

    def to_string(self) -> str:
        """Returns the generated Ylwa string."""
        return self.output
