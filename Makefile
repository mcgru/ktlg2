BIN    := ktlg2
SRC    := src/main.cr
SHARD  := shard.yml

.PHONY: help build static docker test lint format fix check clean

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
	@echo "  check     test + lint + format"
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

check: test lint format

# --- Очистка ---

clean:
	rm -f bin/$(BIN) bin/$(BIN).static
