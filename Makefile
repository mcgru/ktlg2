BIN    := ktlg2
SRC    := src/main.cr
SHARD  := shard.yml

.PHONY: help build static docker test lint format fix check test-install install install-local install-global clean

help:
	@echo "Usage: make <target>"
	@echo
	@echo "Сборка:"
	@echo "  build     release-бинарник bin/$(BIN)"
	@echo "  static    статический бинарник bin/$(BIN).static"
	@echo "  docker    собрать Docker-образ"
	@echo
	@echo "Тесты и качество:"
	@echo "  test      crystal spec"
	@echo "  lint      ameba"
	@echo "  format    проверка форматирования (crystal tool format --check)"
	@echo "  fix       применить форматирование"
	@echo "  check     test + lint + format + test-install"
	@echo
	@echo "Установка:"
	@echo "  install-global   установить в /usr/local/bin (через sudo)"
	@echo "  install-local    установить в ~/.local/bin"
	@echo "  install          подсказка, использовать install-local/install-global"
	@echo "  test-install     spec для make install"
	@echo
	@echo "Прочее:"
	@echo "  clean     удалить бинарники"
	@echo "  help      этот список"

# --- Сборка ---

bin/$(BIN): $(SRC) $(SHARD)
	crystal build $(SRC) --release -o bin/$(BIN)

build: bin/$(BIN)

bin/$(BIN).static: $(SRC) $(SHARD)
	crystal build $(SRC) --release --no-debug --static -o bin/$(BIN).static

static: bin/$(BIN).static

# --- Docker ---

docker:
	docker build -t $(BIN) .

# --- Тесты и качество ---

test:
	crystal spec

lint:
	bin/ameba

format:
	crystal tool format --check

fix:
	crystal tool format

check: test lint format test-install

test-install:
	@bash spec/test_install.sh

# --- Установка ---

BIN_PATH := bin/$(BIN)
SUDO := $(if $(filter root,$(shell whoami 2>/dev/null)),,sudo)
INSTALL_SYSDIR := /usr/local/bin
INSTALL_USERDIR := $(HOME)/.local/bin

install: $(BIN_PATH)
	@echo "Usage: make install-global  (installs to /usr/local/bin via sudo)"
	@echo "       make install-local   (installs to $$HOME/.local/bin)"
	@echo
	@echo "Run one of the above instead."
	@false

install-global: $(BIN_PATH)
	@mkdir -p $(INSTALL_SYSDIR) 2>/dev/null; \
	$(SUDO) cp $(BIN_PATH) $(INSTALL_SYSDIR)/$(BIN); \
	$(SUDO) chmod 755 $(INSTALL_SYSDIR)/$(BIN); \
	echo "Installed: $(INSTALL_SYSDIR)/$(BIN)"

install-local: $(BIN_PATH)
	@mkdir -p $(INSTALL_USERDIR); \
	cp $(BIN_PATH) $(INSTALL_USERDIR)/$(BIN); \
	chmod 755 $(INSTALL_USERDIR)/$(BIN); \
	echo "Installed: $(INSTALL_USERDIR)/$(BIN)"; \
	if ! grep -qs 'HOME/.local/bin' $(HOME)/.bashrc 2>/dev/null && ! grep -qs '~/.local/bin' $(HOME)/.bashrc 2>/dev/null; then \
	  echo; \
	  echo "  NOTE: Add ~/.local/bin to your PATH by running:"; \
	  echo; \
	  echo "    echo 'export PATH=\"\$$HOME/.local/bin:\$$PATH\"' >> ~/.bashrc && source ~/.bashrc"; \
	  echo; \
	fi

# --- Очистка ---

clean:
	rm -f bin/$(BIN) bin/$(BIN).static
