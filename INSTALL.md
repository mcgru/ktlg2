# Установка ktlg2

## Зависимости

**Debian 12 (голая система):**

```bash
# Crystal lang (официальный репозиторий)
curl -fsSL https://packagecloud.io/install/repositories/crystal/install/script.deb.sh | sudo bash
sudo apt-get install -y crystal

# Системные библиотеки для ktlg2
sudo apt-get install -y libexif-dev ffmpeg git make
```

`libexif-dev` нужен для чтения EXIF из JPEG. `ffmpeg` предоставляет `ffprobe` для извлечения даты из MP4/AVI/MOV.

## Сборка

```bash
git clone <url-репозитория>
cd ktlg2

# Установка зависимостей шардов
shards install

# Release-сборка
crystal build src/main.cr --release -o bin/ktlg2
```

## Установка

**Системно (для всех пользователей):**

```bash
sudo cp bin/ktlg2 /usr/local/bin/
```

**В домашнюю директорию (только для текущего пользователя):**

```bash
mkdir -p ~/.local/bin
cp bin/ktlg2 ~/.local/bin/
# Добавьте ~/.local/bin в PATH, если ещё не добавлен:
# echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

## Проверка

```bash
ktlg2 --help
ktlg2 --version
```

## Запуск тестов

```bash
crystal spec
```
