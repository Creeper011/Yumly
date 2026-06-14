MODULE_NAME := libyumly
SRC := src/Yumly/libyumly.nim
OUT_DIR := lib/python/yumly

# Detect environment: prefer .venv if it exists
VENV_BIN := $(shell if [ -d ".venv" ]; then echo ".venv/bin/"; fi)
PYTHON ?= $(VENV_BIN)python3
PIP ?= $(VENV_BIN)pip
NIM ?= nim
NIMBLE ?= nimble
NIM_FLAGS ?= -d:release --opt:size --debuginfo:off --passL:-Wl,--strip-all --lineTrace:off
PYTHON_FLAGS ?= -d:python -d:release --app:lib --opt:size --debuginfo:off --passL:-Wl,--strip-all --lineTrace:off

ifeq ($(OS),Windows_NT)
	EXT := pyd
else
	EXT := so
endif

OUT := $(OUT_DIR)/$(MODULE_NAME).$(EXT)

.PHONY: build build-nim build-py build-cli clean deps deps-full tests help

help:
	@echo "Yumly Makefile"
	@echo "  make deps        Install core Nim dependencies"
	@echo "  make deps-full   Install all dependencies (including YAML)"
	@echo "  make build-py    Build the Nim shared library for Python"
	@echo "  make build-nim   Build the Nim source for Nim use"
	@echo "  make build-cli   Build the Yumly CLI (with JSON and YAML support)"
	@echo "  make tests       Run integration and unit tests"
	@echo "  make clean       Remove build artifacts"

build-py: $(OUT)
	$(PIP) install .

build-nim:
	$(NIM) c $(NIM_FLAGS) $(SRC)

build-cli:
	$(NIM) c $(NIM_FLAGS) -d:yumlyJson -d:yumlyYaml -d:yumlySuggestions -o:yumly-cli utils/yumly_cli.nim

$(OUT): $(SRC)
	@mkdir -p $(OUT_DIR)
	$(NIM) c $(NIM_FLAGS) $(PYTHON_FLAGS) --out:$@ $(SRC)

deps:
	$(NIMBLE) install -y nimpy dotenv

deps-full:
	$(NIMBLE) install -y nimpy dotenv yaml

tests: build-py
	@echo "--- Running Python Runner ---"
	$(PYTHON) -m pytest tests/runners/python_runner.py
	@echo "--- Running Nim Runner ---"
	nim c -r tests/runners/nim_runner.nim


tests-bench: build-py
	@echo "--- Running Python Benchmark Runner ---"
	$(PYTHON) -m pytest tests/runners/python_runner.py --benchmark
	@echo "--- Running Nim Benchmark Runner ---"
	nim c -r tests/runners/nim_runner.nim --benchmark

clean:
	rm -rf $(OUT_DIR)/$(MODULE_NAME).so $(OUT_DIR)/$(MODULE_NAME).pyd
	rm -rf build/ dist/ *.egg-info
	find . -type d -name "__pycache__" -exec rm -rf {} +
