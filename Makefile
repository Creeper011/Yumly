MODULE_NAME := libyumly
SRC := src/Yumly/libyumly.nim
OUT_DIR := lib/python/yumly

# Detect environment: prefer .venv if it exists
VENV_BIN := $(shell if [ -d ".venv" ]; then echo ".venv/bin/"; fi)
PYTHON ?= $(VENV_BIN)python3
PIP ?= $(VENV_BIN)pip
NIM ?= nim
NIMBLE ?= nimble
NIM_FLAGS ?= -d:release --app:lib

ifeq ($(PYTHON),python3)
	PYTHON := python
endif

ifeq ($(OS),Windows_NT)
	EXT := pyd
else
	EXT := so
endif

OUT := $(OUT_DIR)/$(MODULE_NAME).$(EXT)

.PHONY: build clean deps tests help

help:
	@echo "Yumly Makefile"
	@echo "  make deps    Install Nim dependencies"
	@echo "  make build   Build the Nim shared library for Python"
	@echo "  make tests   Run integration and unit tests (like CI)"
	@echo "  make clean   Remove build artifacts"

build: $(OUT)

$(OUT): $(SRC)
	@mkdir -p $(OUT_DIR)
	$(NIM) c $(NIM_FLAGS) --out:$@ $(SRC)

deps:
	$(NIMBLE) install -y nimpy dotenv

tests: build
	@echo "--- Installing Python package ---"
	$(PIP) install -q .
	@echo "--- Running Integration Tests ---"
	$(PYTHON) tests/run_tests.py
	@echo "--- Running Nim Unit Tests ---"
	$(NIM) c -r --path:src tests/components/test_encoder.nim
	$(NIM) c -r --path:src tests/components/test_tokenizer.nim

clean:
	rm -rf $(OUT_DIR)/$(MODULE_NAME).so $(OUT_DIR)/$(MODULE_NAME).pyd
	rm -rf build/ dist/ *.egg-info
	find . -type d -name "__pycache__" -exec rm -rf {} +
