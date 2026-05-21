module Ktlg2
  # Команда organize — основной режим.
  #
  # Раскладывает файлы по папкам:
  # `{path}.years/{год[.суффикс]}/{год-месяц}/`
  #
  # Потом переименовывает `{path}.years` в `{год[-макс]}[.суффикс]`.
  # Исходная папка переименовывается в `{path}.problems`.
  #
  # Полностью повторяет логику bash-скрипта (строки 229-306).
  module Organizer
    extend self

    # Минимальный размер файла в байтах.
    # Файлы меньше считаются битыми и удаляются (как в bash, строка 233).
    MIN_FILE_SIZE = 1000

    def run(config : Config) : Nil
      path = File.realpath(config.path)
      base_name = File.basename(path)
      parent_dir = File.dirname(path)

      # Суффикс темы: из имени исходной папки убрать ведущие цифры, точки, тире.
      suffix = base_name.sub(/^[0-9._-]+/, "")
      suffix = suffix.size > 1 ? suffix : ""

      STDERR.puts "Source: #{path}" if config.verbose
      STDERR.puts "Suffix: '#{suffix}'" if config.verbose

      years_dir = "#{path}.years"

      # 1. Backup существующего .years, если есть.
      backup_existing(years_dir)

      # 2. Собрать все файлы.
      files = collect_files(path)
      return if files.empty?

      STDERR.puts "Files found: #{files.size}" if config.verbose

      # 3. Если dry-run — только показать, не двигать.
      if config.dry_run
        actions = plan_actions(files, path, years_dir, suffix)
        report_actions(actions, config)
        return
      end

      # 4. Создать .years.
      Dir.mkdir(years_dir)

      # 5. Обработать каждый файл.
      actions = plan_actions(files, path, years_dir, suffix)
      execute_actions(actions, config)

      # 6. Удалить пустые папки в исходнике (но не саму исходную папку).
      delete_empty_dirs(path, keep_root: true)

      # 7. Переименовать исходник в .problems.
      problems_dir = "#{path}.problems"
      if Dir.exists?(problems_dir)
        stamp = Time.utc.to_s("%Y%m%d_%H%M%S")
        problems_dir = "#{path}.problems.#{stamp}"
      end

      # Если исходная папка была удалена — пропускаем.
      if Dir.exists?(path)
        File.rename(path, problems_dir)
      end

      # Удалить .problems, если пуста.
      if Dir.exists?(problems_dir)
        begin
          Dir.delete(problems_dir)
        rescue
          # Папка не пуста — оставляем.
        end
      end

      # 8. Переименовать .years в финальное имя.
      final_path = rename_years_dir(years_dir, parent_dir, suffix, config)

      # 9. Почистить двойные вложенности (bash строки 299-302).
      fix_double_subject(final_path, File.basename(final_path))

      # 10. Проставить mtime папок по самому свежему файлу (снизу вверх).
      touch_dirs(final_path)

      STDERR.puts "Done: #{final_path}" if config.verbose
    end

    # --- Сбор файлов ---

    private def collect_files(path : String) : Array(String)
      files = [] of String
      Dir.glob("#{path}/**/*") do |entry|
        next unless File.file?(entry)
        next if File.symlink?(entry)
        files << entry
      end
      files.sort!
    end

    private def backup_existing(dir : String) : Nil
      return unless Dir.exists?(dir)

      stamp = Time.utc.to_s("%Y%m%d_%H%M%S")
      backup = "#{dir}.#{stamp}"
      File.rename(dir, backup)
      STDERR.puts "Backup: #{dir} -> #{backup}"
    end

    # --- Планирование действий ---

    private def plan_actions(
      files : Array(String),
      root : String,
      years_dir : String,
      suffix : String,
    ) : Array(OrganizeAction)
      actions = [] of OrganizeAction

      files.each do |file|
        action = plan_file_action(file, root, years_dir, suffix)
        actions << action if action
      end

      actions
    end

    private def plan_file_action(
      file : String,
      root : String,
      years_dir : String,
      suffix : String,
    ) : OrganizeAction?
      # Проверка на пустой/битый файл.
      file_size = File.size(file)
      if file_size < MIN_FILE_SIZE
        return OrganizeAction.new(file, "", "delete_empty")
      end

      # Извлечь таймстемп.
      ts = Extractor.extract_timestamp(file)
      unless ts
        STDERR.puts "WARNING: cannot determine date for: #{file}"
        return nil
      end

      time = Time.unix(ts.timestamp)
      year = time.to_s("%Y")
      year_month = time.to_s("%Y-%m")

      # Суффикс из относительного пути (очистка числовых префиксов).
      rel_dir = File.dirname(file).sub(root, "")
      subject = extract_subject(rel_dir, year, suffix)

      # Собрать целевую папку.
      target_dir = build_target_dir(years_dir, year, suffix, subject, year_month)

      OrganizeAction.new(file, target_dir, "move")
    end

    # Извлечь суффикс темы из относительного пути.
    # bash, строка 265: очищаем числовые префиксы, склеиваем через точку.
    private def extract_subject(rel_dir : String, year : String, suffix : String = "") : String
      return "" if rel_dir.empty?

      parts = rel_dir.split('/').reject(&.empty?)
      cleaned = parts.map do |part|
        part.sub(/^[0-9._ -]+/, "")
      end.reject(&.empty?)

      return "" if cleaned.empty?

      # bash: sed "s/^/${D1}./" —  year prefix to each component
      prefixed = cleaned.map { |c| "#{year}.#{c}" }

      # Remove component matching base_dir (year.suffix) to avoid
      # duplicating parent directory on re-organize.
      base_dir = suffix.empty? ? year : "#{year}.#{suffix}"
      prefixed = prefixed.reject { |p| p == base_dir }

      prefixed.join(".")
    end

    # Собрать целевую папку.
    # bash, строки 271-274:
    #   PP = "$D1${SPBNsuf:+.$SPBNsuf}"
    #   [ "$PP" != "$SS" ] && PP+="/$SS" ||:
    private def build_target_dir(
      years_dir : String,
      year : String,
      suffix : String,
      subject : String,
      year_month : String,
    ) : String
      base_dir = suffix.empty? ? year : "#{year}.#{suffix}"

      if subject.empty?
        "#{years_dir}/#{base_dir}/#{year_month}"
      else
        "#{years_dir}/#{base_dir}/#{subject}/#{year_month}"
      end
    end

    # --- Исполнение действий ---

    private def execute_actions(
      actions : Array(OrganizeAction),
      config : Config,
    ) : Nil
      actions.each do |action|
        case action.action
        when "move"
          move_file(action.source, action.target)
        when "delete_empty"
          delete_empty_file(action.source)
        end
      end
    end

    # Перенести файл в целевую папку с обработкой коллизий.
    # bash, строки 229-250 (функция move).
    private def move_file(source : String, target_dir : String) : Nil
      basename = File.basename(source)
      target = "#{target_dir}/#{basename}"

      Dir.mkdir_p(target_dir)

      if File.exists?(target)
        # Коллизия: проверяем содержимое.
        source_md5 = md5_first_bytes(source)
        target_md5 = md5_first_bytes(target)

        if source_md5 == target_md5
          # Тот же файл — удаляем дубликат.
          File.delete(source)
          STDERR.puts "Duplicate removed: #{source}"
        else
          # Разные файлы — переименовываем существующий.
          stem = File.basename(target, File.extname(target))
          ext = File.extname(target)
          n = 1
          loop do
            renamed = "#{File.dirname(target)}/#{stem}.(#{n})#{ext}"
            break unless File.exists?(renamed)
            n += 1
          end
          new_name = "#{File.dirname(target)}/#{stem}.(#{n})#{ext}"
          File.rename(target, new_name)
          STDERR.puts "Collision: #{target} -> #{new_name}"

          # Теперь перемещаем исходный файл.
          File.rename(source, target)
          STDERR.puts "Moved: #{source} -> #{target}"
        end
      else
        File.rename(source, target)
        STDERR.puts "Moved: #{source} -> #{target}" if STDERR.tty?
      end
    end

    private def delete_empty_file(path : String) : Nil
      File.delete(path)
      STDERR.puts "Deleted empty: #{path}"
    end

    # --- Финальное переименование ---

    # bash, строки 283-297.
    private def rename_years_dir(
      years_dir : String,
      parent_dir : String,
      suffix : String,
      config : Config,
    ) : String
      final_name = compute_final_name(years_dir, suffix)
      final_path = "#{parent_dir}/#{final_name}"

      if Dir.exists?(final_path)
        # Если уже существует — перемещаем содержимое внутрь.
        Dir.glob("#{years_dir}/*").each do |entry|
          File.rename(entry, "#{final_path}/#{File.basename(entry)}")
        end
        Dir.delete(years_dir)
      else
        File.rename(years_dir, final_path)
      end

      STDERR.puts "Result: #{final_path}"
      final_path
    end

    # Вычислить финальное имя папки.
    # bash, строки 283-291:
    #   minY/maxY из ls .years, если разные — "minY-maxY"
    private def compute_final_name(years_dir : String, suffix : String) : String
      year_dirs = Dir.glob("#{years_dir}/*")
        .select { |e| File.directory?(e) }
        .map { |e| File.basename(e).sub(/\..*/, "") } # только числовой префикс
        .sort!

      return File.basename(years_dir).sub(/\.years$/, "") if year_dirs.empty?

      min_year = year_dirs.first
      max_year = year_dirs.last

      name = if min_year == max_year
               min_year
             else
               "#{min_year}-#{max_year}"
             end

      suffix.empty? ? name : "#{name}.#{suffix}"
    end

    # Почистить двойные вложенности: .../2013.Тема/2013.Тема/...
    # bash, строки 299-302.
    private def fix_double_subject(base_path : String, dir_name : String) : Nil
      double = "#{base_path}/#{dir_name}"
      return unless Dir.exists?(double)

      STDERR.puts "Fixing double subject: #{double}"
      Dir.glob("#{double}/*").each do |entry|
        target = "#{base_path}/#{File.basename(entry)}"
        File.rename(entry, target)
      end
      Dir.delete(double)
    end

    # --- Утилиты ---

    # Проставить mtime на все папки по последнему mtime их содержимого.
    # Обработка снизу вверх: дочерние папки проставляются раньше родительских.
    private def touch_dirs(root : String) : Nil
      dirs = Dir.glob("#{root}/**/").sort!.reverse!

      dirs.each do |dir|
        dir = dir.rstrip('/')
        next if dir == root

        latest = Time.unix(0)
        Dir.glob("#{dir}/*").each do |entry|
          mtime = File.info(entry).modification_time
          latest = mtime if mtime > latest
        end

        File.touch(dir, latest) if latest > Time.unix(0)
      end

      # Корень — последним.
      latest = Time.unix(0)
      Dir.glob("#{root}/*").each do |entry|
        mtime = File.info(entry).modification_time
        latest = mtime if mtime > latest
      end
      File.touch(root, latest) if latest > Time.unix(0)
    end

    private def delete_empty_dirs(path : String, keep_root : Bool = false) : Nil
      loop do
        deleted = false
        Dir.glob("#{path}/**/").sort!.reverse!.each do |dir|
          next unless Dir.exists?(dir)
          next if keep_root && dir.rstrip('/') == path
          begin
            Dir.delete(dir)
            deleted = true
          rescue
            # Папка не пуста — пропускаем.
          end
        end
        break unless deleted
      end
    end

    # MD5 первых 25600 байт файла (как bash: dd if= count=50 bs=512).
    private def md5_first_bytes(path : String) : String
      slice = Bytes.new(25_600)
      bytes_read = File.open(path) { |f| f.read(slice) }
      Digest::MD5.hexdigest(slice[0, bytes_read])
    end

    # --- Отчёт (dry-run / JSON) ---

    private def report_actions(
      actions : Array(OrganizeAction),
      config : Config,
    ) : Nil
      if config.json_output
        puts actions.to_json
      else
        actions.each do |a|
          case a.action
          when "move"
            puts "  #{a.source}  ->  #{a.target}"
          when "delete_empty"
            puts "  DELETE #{a.source} (empty)"
          end
        end
        puts "Total actions: #{actions.size}"
      end
    end
  end
end
