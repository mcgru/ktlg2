require "exif"

module Ktlg2
  # Извлечение даты создания файла из доступных источников.
  #
  # Приоритет (как в bash-оригинале):
  #   1. EXIF — метаданные изображения (JPEG, TIFF)
  #   2. ffprobe — метаданные видео (MP4, MOV, AVI)
  #   3. Имя файла — парсинг даты регулярками
  #   4. Файловая система — mtime (только если нет другого источника)
  #
  # Таймстемпы меньше 1992-01-01 (694202400) считаются невалидными.
  module Extractor
    extend self

    # Расширения изображений, которые могут содержать EXIF.
    IMAGE_EXTS = {"jpg", "jpeg", "tif", "tiff", "png"}
    # Расширения видео, для которых используем ffprobe.
    VIDEO_EXTS  = {"3gp", "avi", "mov", "mp4", "mpg", "mpeg"}

    # Извлечь лучший доступный таймстемп для файла.
    #
    # Возвращает FileTimestamp или nil, если ничего не подошло.
    # Параметр use_filesystem управляет тем, можно ли использовать mtime
    # как источник (touch не должен, чтобы не было круговой логики).
    def extract_timestamp(path : String, use_filesystem : Bool = true) : FileTimestamp?
      ts = extract_exif(path)
      return ts if ts

      ts = extract_video(path)
      return ts if ts

      ts = parse_filename(path)
      return ts if ts

      ts = filesystem_mtime(path)
      return ts if ts && use_filesystem

      nil
    end

    # --- 1. EXIF (изображения) ---

    def extract_exif(path : String) : FileTimestamp?
      ext = File.extname(path).downcase.lstrip('.')
      return nil unless ext.in?(IMAGE_EXTS)

      exif = Exif.new(path)
      raw = exif.date_time_original
      raw ||= exif.date_time_digitized
      raw ||= exif.date_time

      return nil unless raw

      # bash: исключаем 00:00:00 и 000000
      return nil if raw.includes?("00:00:00") || raw.includes?("000000")

      # EXIF формат: "YYYY:MM:DD HH:MM:SS"
      time = Time.parse(raw, "%Y:%m:%d %H:%M:%S", Time::Location::UTC)
      epoch = time.to_unix
      return nil unless valid_timestamp?(epoch)

      FileTimestamp.new(epoch, TimestampSource::Exif)
    rescue
      nil
    end

    # --- 2. Видео (ffprobe) ---

    def extract_video(path : String) : FileTimestamp?
      ext = File.extname(path).downcase.lstrip('.')
      return nil unless ext.in?(VIDEO_EXTS)

      output = IO::Memory.new
      error = IO::Memory.new

      status = Process.run(
        "ffprobe",
        args: ["-v", "quiet", "-print_format", "json", "-show_format", path],
        output: output,
        error: error,
      )

      return nil unless status.success?

      begin
        parsed = JSON.parse(output.to_s)
        creation_time = parsed["format"]?.try &.["tags"]?.try &.["creation_time"]?.try &.as_s?
      rescue
        return nil
      end

      return nil unless creation_time
      return nil if creation_time.includes?("00:00:00") || creation_time.includes?("000000")

      begin
        time = Time.parse_iso8601(creation_time)
        epoch = time.to_unix
        return nil unless valid_timestamp?(epoch)
        FileTimestamp.new(epoch, TimestampSource::Video)
      rescue
        nil
      end
    end

    # --- 3. Имя файла ---

    def parse_filename(path : String) : FileTimestamp?
      basename = File.basename(path)

      # .z. формат (канонический): YYMMDD-HHMMSS.XXXXXXX.z.ext
      epoch = parse_z_format(basename)
      return FileTimestamp.new(epoch, TimestampSource::Filename) if epoch

      # YYYYMMDD[.-]HHMMSS (15 символов: 8+1+6)
      epoch = parse_pattern(basename, /(\d{8})[.\-](\d{6})/)
      return FileTimestamp.new(epoch, TimestampSource::Filename) if epoch

      # YYMMDD[.-]HHMMSS (13 символов: 6+1+6)
      epoch = parse_pattern(basename, /(\d{6})[.\-](\d{6})/)
      return FileTimestamp.new(epoch, TimestampSource::Filename) if epoch

      # 20YYYYMMDD (8 цифр, начинаются с 20)
      epoch = parse_pattern(basename, /(20\d{6})(?:\D|$)/)
      return FileTimestamp.new(epoch, TimestampSource::Filename) if epoch

      # YYMMDD (6 цифр, после них не-цифра)
      epoch = parse_pattern(basename, /(?:[._-]+)(\d{6})(?:\D|$)/)
      return FileTimestamp.new(epoch, TimestampSource::Filename) if epoch

      nil
    end

    # .z. формат: YYMMDD-HHMMSS.XXXXXXX.z.ext
    # bash: split on .z., берём часть до, разбираем по IFS=.-
    private def parse_z_format(basename : String) : Int64?
      return nil unless basename.includes?(".z.")

      prefix = basename.split(".z.")[0]
      return nil unless prefix

      parts = prefix.split(/[.\-]/)
      return nil unless parts.size >= 2

      date_part = parts[0] # YYMMDD
      time_part = parts[1] # HHMMSS

      return nil unless date_part.size == 6 && time_part.size == 6
      return nil unless date_part.to_i? && time_part.to_i?

      epoch = assemble_datetime(date_part, time_part)
      valid_timestamp?(epoch) ? epoch : nil
    end

    # Парсинг по regex: извлекаем date_part и time_part.
    private def parse_pattern(basename : String, pattern : Regex) : Int64?
      match = basename.match(pattern)
      return nil unless match

      date_part = match[1]
      time_part = match[2]? || "000000"

      epoch = assemble_datetime(date_part, time_part)
      valid_timestamp?(epoch) ? epoch : nil
    end

    # Склеить YYMMDD/YYYYMMDD + HHMMSS в Unix timestamp.
    private def assemble_datetime(date : String, time : String) : Int64
      if date.size == 6
        # bash: если год > 50, значит 19YY, иначе 20YY
        prefix = date[0..1].to_i > 50 ? "19" : "20"
        date = "#{prefix}#{date}"
      end

      return 0_i64 unless date.size == 8 && time.size == 6

      year  = date[0..3].to_i
      month = date[4..5].to_i
      day   = date[6..7].to_i
      hour  = time[0..1].to_i
      min   = time[2..3].to_i
      sec   = time[4..5].to_i

      return 0_i64 unless (1970..2100).covers?(year)
      return 0_i64 unless (1..12).covers?(month)
      return 0_i64 unless (1..31).covers?(day)
      return 0_i64 unless (0..23).covers?(hour)
      return 0_i64 unless (0..59).covers?(min)
      return 0_i64 unless (0..59).covers?(sec)

      Time.utc(year, month, day, hour, min, sec).to_unix
    end

    # --- 4. Файловая система ---

    def filesystem_mtime(path : String) : FileTimestamp?
      mtime = File.info(path).modification_time
      epoch = mtime.to_unix
      return nil unless valid_timestamp?(epoch)
      FileTimestamp.new(epoch, TimestampSource::Filesystem)
    end

    # --- Вспомогательное ---

    # bash: таймстемп меньше 1992-01-01 (694202400) считается мусором.
    private def valid_timestamp?(epoch : Int64) : Bool
      epoch >= MIN_VALID_TS
    end
  end
end
