module Ktlg2
  # Разбор аргументов командной строки и диспетчеризация по командам.
  #
  # ```
  # Usage:
  #   ktlg2 [global-opts] [команда|алиас] &lt;PATH&gt;
  #
  # Примеры:
  #   ktlg2 /path/to/photos                   # organize по умолчанию
  #   ktlg2 o /path/to/photos                 # алиас organize
  #   ktlg2 rename --dry-run /path/to/photos  # rename вхолостую
  #   ktlg2 dups --json /path/to/photos       # дубликаты в JSON
  # ```
  module Cli
    # Каноническое имя команды и её алиасы.
    COMMANDS = {
      "organize" => {"o", "org"},
      "rename"   => {"r", "ren"},
      "touch"    => {"t", "tou"},
      "plane"    => {"p", "pla"},
      "check"    => {"c", "chk"},
      "dups"     => {"d", "dup"},
    }

    DEFAULT_COMMAND = "organize"

    # Точка входа: разобрать аргументы и выполнить команду.
    def self.run(args : Array(String)) : Nil
      config = parse_args(args)

      STDERR.puts "Command: #{config.command}" if config.verbose
      STDERR.puts "Path:    #{config.path}" if config.verbose
      STDERR.puts "Jobs:    #{config.jobs}" if config.verbose

      dispatch(config)
    end

    # Разобрать ARGV, вернуть настроенный Config.
    def self.parse_args(args : Array(String)) : Config
      config = Config.new
      positional = [] of String

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: ktlg2 [options] [command] <PATH>"

        opts.on("-v", "--verbose", "Verbose output") do
          config.verbose = true
        end

        opts.on("--dry-run", "Do not change files, just preview") do
          config.dry_run = true
        end

        opts.on("--json", "JSON output (check, dups, dry-run)") do
          config.json_output = true
        end

        opts.on("-j", "--jobs N", "Number of parallel jobs (default: CPU count)") do |num|
          val = num.to_i?
          config.jobs = val.nil? || val <= 0 ? System.cpu_count : val
        end

        opts.on("--apply PATH", "Apply dups resolution from .dups folder") do |apply_path|
          config.apply_path = apply_path
        end

        opts.on("-h", "--help", "Show this help") do
          print_help
          exit(0)
        end

        opts.unknown_args do |unknown|
          positional.concat(unknown)
        end

        opts.invalid_option do |flag|
          STDERR.puts "WARNING: unknown option: #{flag}"
        end
      end

      parser.parse(args)

      # Первый позиционный аргумент может быть командой или алиасом.
      if !positional.empty?
        cmd = recognize_command(positional[0])
        if cmd
          config.command = cmd
          positional.shift
        elsif config.verbose
          STDERR.puts "WARNING: unknown command '#{positional[0]}', using default"
        end
      end

      # Оставшиеся аргументы: ожидаем PATH.
      if !positional.empty?
        config.path = positional[0]
        if positional.size > 1
          STDERR.puts "WARNING: unexpected arguments: #{positional[1..].join(" ")}"
        end
      end

      if config.path.empty?
        STDERR.puts "ERROR: path is required"
        print_help
        exit(1)
      end

      unless Dir.exists?(config.path)
        STDERR.puts "ERROR: path not found or not a directory: #{config.path}"
        exit(1)
      end

      config
    end

    # Проверить, является ли токен известной командой или алиасом.
    # Вернуть каноническое имя или nil.
    def self.recognize_command(token : String) : String?
      COMMANDS.each do |cmd, aliases|
        return cmd if cmd == token || aliases.includes?(token)
      end
      nil
    end

    # Направить выполнение в нужный модуль.
    def self.dispatch(config : Config) : Nil
      case config.command
      when "organize" then Organizer.run(config)
      when "rename"   then Renamer.run(config)
      when "touch"    then Toucher.run(config)
      when "plane"    then Flattener.run(config)
      when "check"    then Checker.run(config)
      when "dups"     then DupFinder.run(config)
      else
        STDERR.puts "ERROR: unknown command '#{config.command}'"
        print_help
        exit(1)
      end
    end

    def self.print_help
      puts "Usage: ktlg2 [options] [command] <PATH>"
      puts
      puts "Commands:"
      COMMANDS.each do |cmd, aliases|
        alias_list = aliases.map { |a| "'#{a}'" }.join(", ")
        puts "  #{cmd.ljust(12)} aliases: #{alias_list}"
      end
      puts "  (default: #{DEFAULT_COMMAND})"
      puts
      puts "Options:"
      puts "  -v, --verbose      Verbose output"
      puts "      --dry-run      Do not change files, just preview"
      puts "      --json         JSON output (check, dups, dry-run)"
      puts "      --help           This help"
      puts "      --apply PATH     Apply dups resolution from .dups folder"
      puts "  -j, --jobs N        Number of parallel jobs (default: CPU count)"
      puts "  -h, --help          This help"
      puts
      puts "Examples:"
      puts "  ktlg2 ~/photos                        # organize (default)"
      puts "  ktlg2 o ~/photos --dry-run --verbose   # preview organize"
      puts "  ktlg2 rename ~/photos                  # rename files"
      puts "  ktlg2 dups --json ~/photos             # duplicates as JSON"
      puts "  ktlg2 dups ~/photos                    # find dups + create .dups hardlinks"
      puts "  ktlg2 dups --apply ~/photos.dups ~/photos  # apply kept copies"
    end
  end
end
