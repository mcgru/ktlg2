# План: ktlg2 на Crystal

Переписать `old.bash/ktlg2.sh` на Crystal.

Crystal 1.20.2 установлен. `ffprobe` доступен. Нужен `libexif-dev` (sudo apt-get install -y libexif-dev).

## Команды и алиасы

| Команда (по умолч. organize) | Алиасы | Назначение |
|-----------------------------|--------|------------|
| `organize` | `o`, `org` | Разложить по папкам Год.Тема/Год-Месяц/ |
| `rename` | `r`, `ren` | Переименовать в YYMMDD-HHMMSS.XXXXXXX.z.ext |
| `touch` | `t`, `tou` | Выставить mtime из метаданных |
| `plane` | `p`, `pla` | Собрать файлы из поддиректорий в корень |
| `check` | `c`, `chk` | Проверить дату в имени vs mtime, сообщить если отличается |
| `dups` | `d`, `dup` | Найти дубликаты (MD5) |

### Глобальные опции

- `--json` — JSON-вывод (check, dups, dry-run)
- `--dry-run` — не двигать файлы
- `-v` / `--verbose`
- `-j` / `--jobs N`

## Структура проекта

```
src/
  ktlg2.cr              — точка входа
  ktlg2/
    cli.cr              — CLI + диспетчеризация
    types.cr            — общие типы
    extractor.cr        — извлечение даты (EXIF -> ffprobe -> имя -> ФС)
    organizer.cr        — organize (основной алгоритм)
    renamer.cr          — rename
    toucher.cr          — touch
    flattener.cr        — plane
    checker.cr          — check
    dup_finder.cr       — dups
spec/
  (по одному spec-файлу на модуль)
```

## Зависимости

- `mamantoha/crystal-exif` — EXIF из JPEG (libexif)
- Stdlib: `OptionParser`, `JSON`, `Digest::MD5`, `File`, `FileUtils`

## Приоритет источников даты

1. EXIF (crystal-exif: DateTimeOriginal -> DateTimeDigitized -> DateTime)
2. ffprobe (Process.run, парсинг JSON, creation_time)
3. Имя файла (regex: .z. -> YYYYMMDD/YYMMDD-HHMMSS -> YYMMDD)
4. Файловая система (File.info.mtime)

Таймстемпы < 694202400 (1992-01-01) считаются невалидными.

## Алгоритм organize

1. Вычислить suffix из имени исходной папки (убрать ведущие цифры/точки/тире)
2. Создать {P}.years/, backup существующего .years
3. Для каждого файла:
   - Извлечь timestamp
   - Год + месяц -> YYYY / YYYY-MM
   - Суффикс темы из относительного пути (очистка числовых префиксов)
   - Цель: {P}.years/{год[.суффикс]}[/{тема}]/{год-месяц}/
4. Коллизия имён:
   - MD5 совпадает -> удалить дубликат
   - MD5 разный -> переименовать существующий с .(N).
5. Удалить пустые папки
6. Переименовать исходник в {P}.problems
7. Переименовать .years -> {год[-конечный]}[.суффикс]
8. Почистить двойные вложенности

## JSON-вывод

- check --json: [{"file","filename_date","mtime_date","match"}]
- dups --json: [{"hash","size","files"}]
- organize --dry-run --json: [{"source","target","action"}]

## Edge-кейсы

- Пустые файлы (< 1000 байт) -> удаляются
- Суффикс из 0-1 символа -> отбрасывается
- Двойной subject -> схлопывается
- Зануленные EXIF-даты (00:00:00) -> игнорируются
- UTF-8 (кириллица) -> родной Crystal String
- --dry-run ничего не двигает

## Тесты

Fixtures: tests/src.files/ — реальные JPG, AVI, папки с кириллицей.
Запуск: crystal spec

## Статус реализации (2026-05-18)

| Шаг | Статус |
|-----|--------|
| Scaffold | ✅ |
| CLI | ✅ |
| Extractor | ✅ |
| Organizer | ✅ |
| Renamer, Toucher, Flattener, Checker, DupFinder | ✅ |
| Specs | ✅ (24 теста, 0 failures) |
| Бинарный файл | ✅ `bin/ktlg2` (4.3 MB) |

**Сборка**: `crystal build src/main.cr -o bin/ktlg2`
**Тесты**: `crystal spec`
**Запуск**: `./bin/ktlg2 [опции] [команда] <PATH>`

**Отложено**:
- `--force` флаг (как в bash)
- Параллельная обработка через fibers/Channel
- Pure Crystal MP4/AVI парсер (пока ffprobe)
- `check` с проверкой имён файлов на недопустимые символы
