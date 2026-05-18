require "json"

module Ktlg2
  # Источник, из которого получена дата файла.
  # Приоритет: Exif -> Video -> Filename -> Filesystem
  enum TimestampSource
    Exif
    Video
    Filename
    Filesystem
  end

  # Результат извлечения даты из файла.
  struct FileTimestamp
    getter timestamp : Int64
    getter source : TimestampSource

    def initialize(@timestamp, @source)
    end
  end

  # Действие, которое выполнит organize (для dry-run / JSON).
  struct OrganizeAction
    getter source : String
    getter target : String
    getter action : String

    def initialize(@source, @target, @action)
    end

    def to_json(builder : JSON::Builder)
      builder.object do
        builder.field "source", @source
        builder.field "target", @target
        builder.field "action", @action
      end
    end
  end

  # Глобальная конфигурация, заполняется из CLI-аргументов.
  class Config
    property path : String
    property verbose : Bool
    property dry_run : Bool
    property json_output : Bool
    property jobs : Int32
    property command : String
    property apply_path : String

    def initialize(@path = "",
                   @verbose = false,
                   @dry_run = false,
                   @json_output = false,
                   @jobs = System.cpu_count,
                   @command = "organize",
                   @apply_path = "")
    end
  end

  # Минимальный валидный timestamp (1992-01-01).
  #bash-скрипт:     694202400
  MIN_VALID_TS = 694_202_400_i64
end
