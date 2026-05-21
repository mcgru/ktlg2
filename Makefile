BIN    := ktlg2
SRC    := src/main.cr
SHARD  := shard.yml

.PHONY: all build static docker test lint format check clean

all: test lint format

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

# --- Всё сразу ---

check: test lint format

# --- Очистка ---

clean:
	rm -f bin/$(BIN) bin/$(BIN).static
