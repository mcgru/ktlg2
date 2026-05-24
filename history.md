# История принятия решений

## 2026-05-18 — Выбор EXIF-библиотеки

**Вопрос**: Почему `mamantoha/crystal-exif`, а не другая?

**Рассмотренные кандидаты**:

| Шард | Тип | Зависимость | Статус |
|------|-----|-------------|--------|
| `mamantoha/crystal-exif` | C-биндинг (libexif) | `libexif-dev` | Стабильный, годы поддержки |
| `Globoplox/make-it-right` | Pure Crystal | Нет | Автор: "not production-ready". Заброшен с 2023 |
| `y2k2mt/exiv2.cr` | C-биндинг (libgexiv2) | `libgexiv2-dev` + glib | v0.1.0, сырой |

**Почему не pure Crystal**: EXIF — сложный формат (endianness, цепочки IFD, вендорские расширения). Стабильный pure Crystal-парсер не найден. `make-it-right` заброшен, автор сам не рекомендует в production.

**Почему не exiv2.cr**: v0.1.0, нестабильный API. Зависимость тяжелее (glib). Для задачи нужен только `DateTimeOriginal` — libexif справляется.

**Почему crystal-exif**: libexif — проверенная C-библиотека, шард покрывает все нужные теги, API минималистичный (`Exif::Data.new(path).to_hash`).

**Риск**: системная зависимость (`libexif-dev`). Решение: принять, т.к. на Linux это пакет на ~200 КБ. Если не хочется ставить — можно сделать fallback на шеллинг внешнего `exif`.

## 2026-05-18 — Итоги реализации ktlg2 на Crystal

**Что сделано**: bash-скрипт `old.bash/ktlg2.sh` переписан на Crystal.

**Команды** (все с алиасами до 1 буквы):
- `organize` (o/org) — раскладка по папкам Год.Тема/Год-Месяц/
- `rename` (r/ren) — переименование в YYMMDD-HHMMSS.XXXXXXX.z.ext
- `touch` (t/tou) — установка mtime из метаданных
- `plane` (p/pla) — сбор файлов из поддиректорий в корень
- `check` (c/chk) — проверка даты в имени vs mtime
- `dups` (d/dup) — поиск дубликатов по MD5

**Приоритет извлечения даты**: EXIF (crystal-exif) → ffprobe → имя файла → ФС.

**Архитектура**:
- `src/main.cr` — точка входа
- `src/ktlg2.cr` — библиотека (подключает модули)
- `src/ktlg2/` — 9 модулей (types, cli, extractor, organizer, renamer, toucher, flattener, checker, dup_finder)
- `spec/` — 3 файла тестов (cli, extractor, organizer), 24 примера

**Зависимости**: `mamantoha/crystal-exif` + Crystal stdlib.

**Исполняемый файл**: `bin/ktlg2` (4.3 MB).

**Тесты**: `crystal spec` — 24 examples, 0 failures, 0 errors.

**Ключевые решения**:
- Разделение библиотеки (`src/ktlg2.cr`) и точки входа (`src/main.cr`), чтобы spec не запускал CLI
- Использование `JSON::Builder` для ручной сериализации вместо `JSON::Serializable` (недоступен в Crystal 1.20)
- `OrganizeAction` как struct с `to_json` для JSON-вывода dry-run
- `delete_empty_dirs` с флагом `keep_root` чтобы не удалить исходную папку до переименования в .problems

## 2026-05-18 — Правки organizer

**Проблема 1**: После переименования исходной папки в `.problems` она оставалась на диске даже пустой.

**Решение**: Добавлена проверка — если `.problems` пуст, он удаляется (`Dir.delete` с `rescue` для непустого случая).

**Проблема 2**: Вложенные папки с темами (например, `2013.Москва-Саша-Наташа/`) теряли год в суффиксе темы, потому что `extract_subject` очищал числовые префиксы, но не подставлял год обратно. В bash это делал `sed "s/^/${D1}./"`.

**Решение**: В `extract_subject` год теперь подставляется префиксом к каждому компоненту пути:
```crystal
prefixed = cleaned.map { |c| "#{year}.#{c}" }
```
Например, файл из `2013.Москва-Саша-Наташа/` с годом 2013 → суффикс `2013.Москва-Саша-Наташа` вместо `Москва-Саша-Наташа`.

## 2026-05-18 — Dups: hardlink-копии в .dups и --apply

**Задача**: Упростить ручной разбор дубликатов — создать browsable-структуру с hardlink-копиями и дать возможность применить решение обратно.

**Режимы**:
1. `ktlg2 dups /path` — находит дубликаты (полный MD5) и создаёт `{path}.dups/{hash}/rel/path/file` — hardlink-копии, сгруппированные по хешу с сохранением оригинальной структуры директорий.
2. `ktlg2 dups --apply /path.dups /path` — синхронизирует решение обратно: файлы, чей hardlink остался в `.dups` — "keepers", остальные с тем же содержимым перемещаются в `.problems`. Уникальные файлы (не дубликаты) не трогаются.

**Зачем hardlink'и**: Занимают 0 дополнительного места на диске (та же inode). User может безопасно удалять из `.dups/*/` неугодные копии — это не затрагивает оригиналы (просто снимает directory entry). `--apply` смотрит, какие hardlink'и остались, и переносит решение на исходную папку.

**Изменённые файлы**:
- `types.cr` — Config: добавлено поле `apply_path`
- `cli.cr` — OptionParser: добавлен `--apply PATH`, обновлён help
- `dup_finder.cr` — добавлены `create_dup_links` и `run_apply`

**Производительность**: Для --apply требуется полный MD5 каждого файла в целевой папке. Принято как неизбежное — альтернативы (inode-сравнение) не работают, т.к. hardlink из `.dups` может быть удалён, а оригинал остаётся.

## 2026-05-18 — CLI переведён на OptionParser

**Что было**: Ручной разбор `while i < args.size` / `case arg/when` с самостоятельной обработкой `-j` значения, `--help` и неизвестных флагов.

**Что стало**: `OptionParser.parse(args)` из stdlib. Флаги регистрируются через `parser.on(...)`, значения аргументов (jobs) принимаются через блок, неизвестные флаги — `parser.invalid_option`, позиционные аргументы — `parser.unknown_args`.

**Зачем**: Меньше кода (—25 строк), стандартный парсинг без велосипедов, автоматическая обработка `--` и склейки коротких флагов.

**Отложено**:
- Pure Crystal MP4/AVI парсер (пока ffprobe)
- Поддержка `--force` (как в bash)
- Параллельная обработка через `spawn`/`Channel`
- `check` с проверкой имен файлов (пока только даты)

## 2026-05-19 — Git init, документация, Debian-пакет, bump-version

**Git**: Репозиторий инициализирован, первый коммит (23 файла). В `.gitignore`: `.claude/`, `lib/`, `tests/src.files`, `old.bash/`, `bin/`, `*.deb`.

**INSTALL.md**: Инструкция для Debian 12 — установка Crystal (официальный репозиторий), `libexif-dev`, `ffmpeg`, затем `shards install` + `crystal build --release`. Два варианта установки: системно (`/usr/local/bin/`) или в домашку (`~/.local/bin/`).

**Debian-пакет**: `distrib/debian/create-deb.sh` собирает `.deb` c зависимостями `libexif12, ffmpeg, libpcre2-8-0`. Бинарник кладётся в `/usr/bin/ktlg2`. Версия и мейнтейнер настраиваются через переменные окружения.

**bump-version**: `distrib/bump-version.sh` анализирует `git log` от последнего тега до HEAD по Conventional Commits: `feat` → minor, `fix`/прочее → patch, `!` → major. Правит `version` в `shard.yml` и печатает команды для коммита и тега.

**README.md**: Создан с описанием команд и примерами использования.

**Версия**: 0.1.0 → 0.1.3 (документационные и инфраструктурные коммиты).

## 2026-05-21 — Code quality, CI/CD, тесты, Dockerfile, docs, Makefile

**Code quality**:
- Ameba (v1.6.4) добавлен как dev-зависимость — 0 failures на 22 файлах
- `.ameba.yml` с конфигом (отключены BlockParameterName, VerboseBlock, QueryBoolMethods, CyclomaticComplexity)
- `src/ktlg2/version.cr` — константа `Ktlg2::VERSION`
- Исправлены shadowing, unused args, `.sort` → `.sort!`, `.any?` → `!.empty?`

**CI/CD** (`.github/workflows/`):
- `ci.yml` — 4 jobs: format → lint → test (matrix: latest, 1.15, 1.14) → build. Кэширование shards через `hashFiles(shard.lock)`
- `release.yml` — на тег `v*`: сборка под linux x86_64, macOS x86_64, macOS arm64 + GitHub Release с `generate_release_notes`

**Тесты**: +5 spec-файлов (renamer, toucher, flattener, checker, dup_finder). Итого 37 examples, 0 failures.

**Dockerfile**: Multi-stage — `crystallang/crystal:1.20-alpine` (builder) → `alpine:3.23` (runtime). Сборка `--static --release`.

**Документация**: Doc-комментарии во всех модулях, `crystal docs` генерирует HTML.

**Makefile**: Цели build, static, docker, test, lint, format/fix, check, clean, help (по умолчанию).

## 2026-05-21 — version.cr читает версию из shard.yml

**Проблема**: Версия дублировалась в `shard.yml` и `src/ktlg2/version.cr`. При bump'е через `distrib/bump-version.sh` правился только `shard.yml`, рассинхрон.

**Решение**: Макрос времени компиляции в `version.cr`:
```crystal
VERSION = {{ read_file("./shard.yml").split('\n').find(&.starts_with?("version: ")).gsub(/version: /, "").strip }}
```
Единственный источник истины — `shard.yml`. `version.cr` получает значение автоматически при каждой компиляции.

## 2026-05-21 — --version флаг, фикс help, Ameba в CI

**`--version`**: Добавлен флаг `-V`/`--version` в OptionParser. Выводит `ktlg2 v<VERSION>` из `Ktlg2::VERSION`.

**help**: Убрано дублирование `--help` в выводе `print_help` (было дважды).

**CI**: В `ci.yml` добавлен шаг сборки `bin/ameba` перед запуском линтера.

**Release**: В `release.yml` закомментированы сборки под macOS (не тестируются).

## 2026-05-21 — CI: фикс lint (bin/ не существует)

В `ci.yml` добавлен `mkdir -p bin` перед сборкой ameba и ktlg2 — в GitHub Actions директория `bin/` отсутствует, и `ld` не может создать выходной файл.

## 2026-05-21 — make install

**Makefile**: Добавлена цель `install`. Сначала пытается установить в `/usr/local/bin` через sudo. Если sudo недоступен — ставит в `~/.local/bin` и предлагает добавить его в PATH через `.bashrc`, если его там нет.

## 2026-05-21 — make install разделён на install-local и install-global

`make install` теперь выводит подсказку с предложением запустить `make install-local` или `make install-global` и завершается с ошибкой. `install-global` ставит в `/usr/local/bin` через sudo, `install-local` — в `~/.local/bin` с проверкой PATH в `.bashrc`.

## 2026-05-21 — spec для make install

`spec/test_install.sh` — bash-тесты для `install`, `install-local`, `install-global`:
- установка бинарника в нужную директорию
- подсказка PATH, когда `.bashrc` не содержит `~/.local/bin`
- отсутствие подсказки, когда PATH уже настроен
- `make install` показывает инструкцию и завершается с ошибкой
- `install-global` проверяется через dry-run

Добавлен `make test-install`, включён в `make check`.

## 2026-05-21 — INSTALL.md переписан

Обновлён `INSTALL.md` — задокументированы все 4 способа установки на чистый Debian/Ubuntu:
1. ручная сборка (`crystal build`) + копирование бинарника
2. `make install-local` / `make install-global`
3. Docker (`make docker`, `docker run -v`)
4. deb-пакет (`create-deb.sh` + `dpkg -i`)

## 2026-05-21 — deps-check / deps-install в Makefile

`make deps-check` проверяет наличие crystal, ffprobe, git, make, libexif-dev. Если чего-то не хватает — показывает список и завершается с ошибкой, предлагая `make deps-install`.

`make deps-install` печатает команду для установки всех зависимостей на Debian/Ubuntu (curl + apt-get).

## 2026-05-21 — deps-install: удобный копипаст

`make deps-install` теперь выводит `curl | sudo bash` и `sudo apt-get install` на отдельных строках, чтобы каждую можно было выделить и скопировать дабл-кликом.

## 2026-05-21 — make bump

Добавлен `make bump` — запускает `distrib/bump-version.sh`, который анализирует `git log` от последнего тега по Conventional Commits, обновляет `shard.yml` и печатает команды для коммита и тега.

## 2026-05-21 — make build: создание bin/ перед сборкой

В `make build` и `make static` добавлен `mkdir -p bin` — при отсутствии директории `bin/` линкер (`ld`) не может записать выходной файл.

## 2026-05-21 — libgc-dev добавлен в зависимости

`libgc-dev` (Boehm GC, нужен для линковки Crystal) добавлен в `DEPS_PKG`, `deps-check`, `deps-install` и `INSTALL.md`.

## 2026-05-24 — Makefile: deb-цель

**Что**: Добавлена make-цель `deb`, которая вызывает `distrib/debian/create-deb.sh`.
Цель добавлена в `.PHONY` и справку `make help`.
`deb` зависит от `bin/ktlg2` — при изменении исходников make сначала пересобирает бинарник.
Скрипт `create-deb.sh` больше не запускает `crystal build`, только проверяет наличие бинарника.

**Зачем**: Чтобы сборка .deb-пакета была на одном уровне с `make docker` — не нужно помнить путь к скрипту.

## 2026-05-24 — deb-static

**Что**: Добавлена `make deb-static` — собирает .deb со статическим бинарником (`bin/ktlg2.static`).
Бинарник внутри .deb называется `ktlg2`, имя файла — `ktlg2_*_static_amd64.deb`.
Зависимости для static-deb: только `ffmpeg` (libexif и pcre2 статически слинкованы).

**Изменения**:
- `Makefile`: цель `deb-static` с зависимостью от `bin/ktlg2.static`
- `create-deb.sh`: параметры `BINARY` и `PKG_SUFFIX`, автовыбор `DEPS`

## 2026-05-24 — EXIF SIGSEGV fix + test-my-case.sh

**Проблема**: `extract_exif` падал с signal 11 на JPEG без EXIF или с повреждёнными метаданными.
Корень: `Exif.new(path)` в crystal-exif не проверяет `null` от `libexif` (`exif_data_new_from_file`),
и разыменование нулевого указателя в `initialize` роняет процесс — `rescue` сигналы не ловит.

**Решение**: Переписан `extract_exif` на прямые вызовы `LibExif` с null-чеками на каждом уровне:
- `exif_data_new_from_file` → `nil` если null
- IFD-контент (`ifd[ifd.value]`) → `nil` если null
- `exif_content_get_entry` → `nil` если null
- `exif_entry_get_value` → `nil` если null
- Освобождение: только `exif_data_free` (без лишнего `unref`)

**test-my-case.sh**: Добавлен скрипт `distrib/test-my-case.sh`, который копирует `tests/data/` →
`tests/target/` и прогоняет указанную команду ktlg2. Цель `make tests` прогоняет все 6 команд
последовательно. Все проходят (6/6 OK).

**Изменённые файлы**:
- `src/ktlg2/extractor.cr` — null-safe `extract_exif` через `LibExif`
- `Makefile` — цель `tests`
- `distrib/test-my-case.sh` — новый скрипт
