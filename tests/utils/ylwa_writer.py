"""
A mini library to construct Ylwa files programmatically.
Ylwa is a representative language for benchmarking.
"""

class YlwaWriter:
    def __init__(self):
        self.output = ""
        self.indent_level = 0

    def _indent(self) -> str:
        return "  " * self.indent_level

    def _validate_identifier(self, identifier: str):
        if not identifier:
            raise ValueError("Ylwa identifier cannot be empty")
        for character in identifier:
            if character in (';', ':', '\n', '\r', ','):
                raise ValueError(f"Invalid character in Ylwa identifier: {character}")

    def _validate_value(self, value: str):
        for character in value:
            if character in (',', ';', ':', '<', '>'):
                raise ValueError(f"Invalid character in Ylwa value: {character}")

    def add_comment(self, comment: str):
        """Adds a multiline comment block (.> ... <.)"""
        indent = self._indent()
        comment_lines = comment.replace("\n", f"\n{indent}  ")
        self.output += f"{indent}.> {comment_lines} <.\n\n"

    def begin_block(self, name: str):
        """Starts a block (~ Name :)"""
        self._validate_identifier(name)
        self.output += f"{self._indent()}~ {name} :\n"
        self.indent_level += 1

    def add_field(self, name: str, value: str, comment: str = ""):
        """Adds a field-value pair (- Name ; Value,)"""
        self._validate_identifier(name)
        self._validate_value(value)
        self.output += f"{self._indent()}- {name} ; {value},"
        if comment:
            self.output += f" .> {comment} <."
        self.output += "\n"

    def end_block(self):
        """Ends the current block (:)"""
        if self.indent_level > 0:
            self.indent_level -= 1
        self.output += f"{self._indent()}:\n\n"

    def to_string(self) -> str:
        """Returns the generated Ylwa string."""
        return self.output
