MODULE_NAME := yumly_core
SRC := yumly/yumly_core.nim
OUT_DIR := lib/python/yumly

PYTHON ?= python3
NIM ?= nim
NIMBLE ?= nimble
NIM_FLAGS ?= -d:release --app:lib

ifeq ($(OS),Windows_NT)
	EXT := pyd
else
	EXT := so
endif

OUT := $(OUT_DIR)/$(MODULE_NAME).$(EXT)

.PHONY: build clean deps

build: $(OUT)

$(OUT): $(SRC)
	@mkdir -p $(OUT_DIR)
	$(NIM) c $(NIM_FLAGS) --out:$@ $(SRC)

deps:
	$(NIMBLE) install -y nimpy dotenv

clean:
	rm -f $(OUT_DIR)/$(MODULE_NAME).so $(OUT_DIR)/$(MODULE_NAME).pyd
