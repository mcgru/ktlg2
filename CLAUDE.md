# ktlg2

Утилита на Crystal для каталогизации медиафайлов (JPEG, PNG, MP4, AVI, MOV).

Портирует `old.bash/ktlg2.sh` на Crystal с сохранением всей функциональности.

## Команды

| Команда | Алиасы | Назначение |
|---------|--------|------------|
| `organize` (default) | `o`, `org` | Разложить по папкам Год.Тема/Год-Месяц/ |
| `rename` | `r`, `ren` | Переименовать в YYMMDD-HHMMSS.XXXXXXX.z.ext |
| `touch` | `t`, `tou` | Выставить mtime из метаданных |
| `plane` | `p`, `pla` | Собрать файлы из поддиректорий в корень |
| `check` | `c`, `chk` | Проверить дату в имени vs mtime |
| `dups` | `d`, `dup` | Найти дубликаты (MD5) |

## Приоритет извлечения даты

1. **EXIF** — crystal-exif (libexif): DateTimeOriginal → DateTimeDigitized → DateTime
2. **ffprobe** — Process.run, creation_time из JSON
3. **Имя файла** — regex: .z. → YYYYMMDD/YYMMDD-HHMMSS → YYMMDD
4. **Файловая система** — File.info.mtime

Таймстемпы < 694202400 (1992-01-01) считаются невалидными.

## Сборка и тесты

```bash
# Сборка
crystal build src/main.cr -o bin/ktlg2

# Тесты (24 examples, 0 failures)
crystal spec

# Использование
./bin/ktlg2 ~/photos                    # organize (default)
./bin/ktlg2 o ~/photos --dry-run -v     # preview
./bin/ktlg2 rename ~/photos             # rename
./bin/ktlg2 dups --json ~/photos        # duplicates as JSON
```

## Зависимости

- `mamantoha/crystal-exif` — EXIF (требует `libexif-dev`)
- `ffprobe` — для видеоформатов
- Stdlib: `OptionParser`, `JSON`, `Digest::MD5`, `File`, `FileUtils`

## Структура

```
src/
  main.cr              — точка входа
  ktlg2.cr             — библиотека
  ktlg2/
    types.cr           — общие типы и конфиг
    cli.cr             — CLI, алиасы, dispatch
    extractor.cr       — извлечение даты
    organizer.cr       — сортировка по папкам
    renamer.cr         — переименование
    toucher.cr         — touch
    flattener.cr       — plane
    checker.cr         — check
    dup_finder.cr      — dups
spec/
    spec_helper.cr
    cli_spec.cr
    extractor_spec.cr
    organizer_spec.cr
```

## Старый Rust-план

В `plan-rust.md` лежит Rust-версия плана, которая не была реализована.
