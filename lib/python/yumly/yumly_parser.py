from .yumly_error import YumlyError

class _YumlyParser():
    """Parser for the raw string returned by the Yumly library."""
    def __init__(self, text: str):
        self.text = text
        self.i = 0
        self.n = len(text)

    def ensure_end(self):
        self._skip_ws()
        if self.i != self.n:
            raise YumlyError("Oh no.. an unexpected error ocurred.. :( trailing data in parser output")

    def _skip_ws(self):
        while self.i < self.n and self.text[self.i].isspace():
            self.i += 1

    def _consume(self, ch: str):
        self._skip_ws()
        if self.i >= self.n or self.text[self.i] != ch:
            found = self.text[self.i] if self.i < self.n else "EOF"
            raise YumlyError(f"Oh no.. an unexpected error ocurred.. :( expected '{ch}', found '{found}'")
        self.i += 1

    def parse_value(self):
        self._skip_ws()
        if self.i >= self.n:
            raise YumlyError("Oh no.. an unexpected error ocurred.. :( unexpected end of parser output")

        ch = self.text[self.i]
        if ch == 'S':
            return self._parse_string()
        if ch == 'I':
            return self._parse_int()
        if ch == 'F':
            return self._parse_float()
        if ch == 'B':
            return self._parse_bool()
        if ch == 'M':
            return self._parse_map()
        if ch == 'L':
            return self._parse_list()
        raise YumlyError(f"Oh no.. an unexpected error ocurred.. :( invalid value tag '{ch}'")

    def _parse_length(self) -> int:
        start = self.i
        while self.i < self.n and self.text[self.i].isdigit():
            self.i += 1
        if self.i == start or self.i >= self.n or self.text[self.i] != ':':
            raise YumlyError("Oh no.. an unexpected error ocurred.. :( invalid length in parser output")
        length = int(self.text[start:self.i])
        self.i += 1
        return length

    def _parse_string(self) -> str:
        self._consume('S')
        length = self._parse_length()
        if self.i + length > self.n:
            raise YumlyError("Oh no.. an unexpected error ocurred.. :( string out of bounds")
        s = self.text[self.i:self.i + length]
        self.i += length
        return s

    def _parse_int(self) -> int:
        self._consume('I')
        length = self._parse_length()
        if self.i + length > self.n:
            raise YumlyError("Oh no.. an unexpected error ocurred.. :( int out of bounds")
        s = self.text[self.i:self.i + length]
        self.i += length
        try:
            return int(s)
        except ValueError as exc:
            raise YumlyError("Oh no.. an unexpected error ocurred.. :( invalid int value") from exc

    def _parse_float(self) -> float:
        self._consume('F')
        length = self._parse_length()
        if self.i + length > self.n:
            raise YumlyError("Oh no.. an unexpected error ocurred.. :( float out of bounds")
        s = self.text[self.i:self.i + length]
        self.i += length
        try:
            return float(s)
        except ValueError as exc:
            raise YumlyError("Oh no.. an unexpected error ocurred.. :( invalid float value") from exc

    def _parse_bool(self) -> bool:
        self._consume('B')
        if self.i >= self.n:
            raise YumlyError("Oh no.. an unexpected error ocurred.. :( bool out of bounds")
        ch = self.text[self.i]
        self.i += 1
        if ch == '1':
            return True
        if ch == '0':
            return False
        raise YumlyError("Oh no.. an unexpected error ocurred.. :( invalid bool value")

    def _parse_count(self, opener: str) -> int:
        start = self.i
        while self.i < self.n and self.text[self.i].isdigit():
            self.i += 1
        if self.i == start or self.i >= self.n or self.text[self.i] != opener:
            raise YumlyError("Oh no.. an unexpected error ocurred.. :( invalid container header")
        count = int(self.text[start:self.i])
        self.i += 1
        return count

    def _parse_map(self) -> dict:
        self._consume('M')
        count = self._parse_count('{')
        out = {}
        for _ in range(count):
            key = self._parse_string()
            out[key] = self.parse_value()
        self._consume('}')
        return out

    def _parse_list(self) -> list:
        self._consume('L')
        count = self._parse_count('[')
        items = []
        for _ in range(count):
            items.append(self.parse_value())
        self._consume(']')
        return items
