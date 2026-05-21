# Установка ktlg2

## Зависимости

**Debian / Ubuntu (голая система):**

```bash
# Crystal lang (официальный репозиторий)
curl -fsSL https://crystal-lang.org/install.sh | sudo bash
sudo apt-get install -y crystal

# Системные библиотеки для ktlg2
sudo apt-get install -y libexif-dev libgc-dev ffmpeg git make
```

`libexif-dev` нужен для чтения EXIF из JPEG. `libgc-dev` — сборщик мусора для Crystal (Boehm GC). `ffmpeg` предоставляет `ffprobe` для извлечения даты из MP4/AVI/MOV.

---

## Способы установки

### 1. Сборка из исходников + ручная установка

```bash
git clone https://github.com/mcgru/ktlg2.git
cd ktlg2
shards install
mkdir -p bin
crystal build src/main.cr --release -o bin/ktlg2

# Системно (для всех пользователей):
sudo cp bin/ktlg2 /usr/local/bin/

# Или в домашнюю директорию:
mkdir -p ~/.local/bin
cp bin/ktlg2 ~/.local/bin/
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 2. Через Makefile

```bash
git clone https://github.com/mcgru/ktlg2.git
cd ktlg2
shards install

# Глобально (через sudo):
make install-global

# Локально (для текущего пользователя):
make install-local
# Makefile сам добавит ~/.local/bin в PATH, если его нет в .bashrc
```

### 3. Через Docker

```bash
git clone https://github.com/mcgru/ktlg2.git
cd ktlg2

# Собрать образ:
make docker
# или: docker build -t ktlg2 .

# Запуск (проброс папки с фото):
docker run --rm -v /path/to/photos:/data ktlg2 /data
docker run --rm -v /path/to/photos:/data ktlg2 rename /data
```

Статический бинарник внутри образа — не требует libexif/ffmpeg на хосте. Но `ffprobe` для видео не будет работать (нет ffmpeg внутри контейнера, если не установлен на хосте и не примонтирован).

### 4. Deb-пакет

```bash
git clone https://github.com/mcgru/ktlg2.git
cd ktlg2
shards install

# Собрать .deb:
./distrib/debian/create-deb.sh

# Установить:
sudo dpkg -i ktlg2_*.deb

# Если dpkg жалуется на зависимости:
sudo apt-get install -f
```

Пакет устанавливает бинарник в `/usr/bin/ktlg2` и содержит зависимости `libexif12`, `ffmpeg`, `libpcre2-8-0`.

---

## Проверка

```bash
ktlg2 --help
ktlg2 --version
```

## Запуск тестов

```bash
crystal spec
make test        # то же самое
make check       # тесты + линтер + форматирование
make test-install  # тесты make install
```
