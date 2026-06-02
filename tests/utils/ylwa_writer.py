"""
A mini library to construct Ylwa files programmatically.
Ylwa is a representative language for benchmarking.
"""

class YlwaWriter:
    def __init__(self):
        self.output = ""

    def _validate_identifier(self, identifier: str):
        if not identifier:
            raise ValueError("Ylwa identifier cannot be empty")
        for character in identifier:
            if character in (';', '\n', '\r', ','):
                raise ValueError(f"Invalid character in Ylwa identifier: {character}")

    def _validate_value(self, value: str):
        for character in value:
            if character in (',', ';', ':', '<', '>'):
                raise ValueError(f"Invalid character in Ylwa value: {character}")

    def add_comment(self, comment: str):
        """Adds a multiline comment block (.> ... <.)"""
        comment_lines = comment.replace("\n", "\n  ")
        self.output += f".> {comment_lines} <.\n\n"

    def begin_block(self, name: str):
        """Starts a block (~ Name :)"""
        self._validate_identifier(name)
        self.output += f"~ {name} :\n"

    def add_field(self, name: str, value: str, comment: str = ""):
        """Adds a field-value pair (- Name ; Value,)"""
        self._validate_identifier(name)
        self._validate_value(value)
        self.output += f"  - {name} ; {value},"
        if comment:
            self.output += f" .> {comment} <."
        self.output += "\n"

    def end_block(self):
        """Ends the current block (:)"""
        self.output += ":\n\n"

    def to_string(self) -> str:
        """Returns the generated Ylwa string."""
        return self.output
