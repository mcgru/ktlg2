BIN    := ktlg2
SRC    := src/main.cr
SHARD  := shard.yml

.PHONY: help build static docker deb deb-static tests test lint format fix check test-install deps-check deps-install bump install install-local install-global clean

help:
	@echo "Usage: make <target>"
	@echo
	@echo "Сборка:"
	@echo "  build     release-бинарник bin/$(BIN)"
	@echo "  static    статический бинарник bin/$(BIN).static"
	@echo "  docker    собрать Docker-образ"
	@echo "  deb       собрать .deb-пакет"
	@echo "  deb-static собрать .deb-пакет со статическим бинарником"
	@echo
	@echo "Тесты и качество:"
	@echo "  test      crystal spec"
	@echo "  tests     прогнать все 6 команд ktlg2 на тестовых данных"
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
	@echo "Зависимости:"
	@echo "  deps-check     проверить наличие системных зависимостей"
	@echo "  deps-install   показать команду для установки зависимостей"
	@echo
	@echo "Версионирование:"
	@echo "  bump      увеличить версию по коммитам (Conventional Commits)"
	@echo
	@echo "Прочее:"
	@echo "  clean     удалить бинарники"
	@echo "  help      этот список"

# --- Сборка ---

bin/$(BIN): $(SRC) $(SHARD)
	mkdir -p bin
	crystal build $(SRC) --release -o bin/$(BIN)

build: bin/$(BIN)

bin/$(BIN).static: $(SRC) $(SHARD)
	mkdir -p bin
	crystal build $(SRC) --release --no-debug --static -o bin/$(BIN).static

static: bin/$(BIN).static

# --- Docker ---

docker:
	docker build -t $(BIN) .

# --- Deb-пакет ---

deb: bin/$(BIN)
	@bash distrib/debian/create-deb.sh

deb-static: bin/$(BIN).static
	BINARY=bin/$(BIN).static PKG_SUFFIX=static bash distrib/debian/create-deb.sh

# --- Тесты и качество ---

test:
	crystal spec

tests: bin/$(BIN)
	@bash distrib/test-my-case.sh organize && \
	  bash distrib/test-my-case.sh rename && \
	  bash distrib/test-my-case.sh touch && \
	  bash distrib/test-my-case.sh plane && \
	  bash distrib/test-my-case.sh check && \
	  bash distrib/test-my-case.sh dups && \
	  echo "" && echo "All tests passed."

lint:
	bin/ameba

format:
	crystal tool format --check

fix:
	crystal tool format

check: test lint format test-install

test-install:
	@bash spec/test_install.sh

# --- Зависимости ---

DEPS_BIN     := crystal ffprobe git make
DEPS_PKG     := libexif-dev libgc-dev ffmpeg git make
###DEPS_REPO    := https://packagecloud.io/install/repositories/crystal/install/script.deb.sh
DEPS_REPO    := curl -fsSL https://crystal-lang.org/install.sh
deps-check:
	@echo "Checking dependencies..."; \
	missing=""; \
	for bin in $(DEPS_BIN); do \
	  if command -v $$bin >/dev/null 2>&1; then \
	    echo "  [ok]  $$bin"; \
	  else \
	    echo "  [missing]  $$bin"; \
	    missing="$$missing $$bin"; \
	  fi; \
	done; \
	for pkg in libexif-dev libgc-dev; do \
	  if dpkg -l $$pkg >/dev/null 2>&1; then \
	    echo "  [ok]  $$pkg"; \
	  else \
	    echo "  [missing]  $$pkg"; \
	    missing="$$missing $$pkg"; \
	  fi; \
	done; \
	if [ -n "$$missing" ]; then \
	  echo; \
	  echo "  Run: make deps-install"; \
	  exit 1; \
	else \
	  echo; \
	  echo "All dependencies satisfied."; \
	fi

deps-install:
	@echo "Install system dependencies:"
	@echo
	@echo "  curl -fsSL $(DEPS_REPO) | sudo bash"
	@echo
	@echo "  sudo apt-get install -y $(DEPS_PKG)"
	@echo

# --- Версионирование ---

bump:
	@bash distrib/bump-version.sh

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
