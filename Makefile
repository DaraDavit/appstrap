PREFIX    ?= $(HOME)/.local
BIN        := build/appstrap
CONFIG_DIR := $(HOME)/.config/appstrap
CMD       ?= select

.PHONY: build run install clean

build:
	cmake -B build
	cmake --build build

run: build
	$(BIN) $(CMD) $(ARGS)

install: build
	install -Dm755 $(BIN) "$(PREFIX)/bin/appstrap"
	install -Dm644 packages.json "$(CONFIG_DIR)/packages.json"
	@echo "installed appstrap -> $(PREFIX)/bin/appstrap"
	@echo "manifest             -> $(CONFIG_DIR)/packages.json"

clean:
	rm -rf build
