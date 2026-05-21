module Ktlg2
  # Команда dups.
  #
  # Ищет дубликаты по содержимому (полный MD5).
  #
  # ## Режимы
  #
  # **Без --apply**: найти дубликаты + создать `{path}.dups` с hardlink-копиями.
  #
  # **С --apply**: прочитать `.dups`, оставить только файлы, отмеченные
  # пользователем, остальные переместить в `.problems`.
  #
  # ## Структура .dups
  #
  # `{path}.dups/{hash}/{rel/path/file}` (hardlink)
  #
  # ## Workflow
  #
  # 1. `ktlg2 dups /path` — найти дубликаты, создать `.dups`
  # 2. (руками удалить лишнее из `.dups/*/`)
  # 3. `ktlg2 dups --apply /path.dups /path` — применить решение
  module DupFinder
    extend self

    def run(config : Config) : Nil
      if !config.apply_path.empty?
        run_apply(config)
        return
      end

      path = File.realpath(config.path)

      files = Dir.glob("#{path}/**/*")
        .select { |e| File.file?(e) && !File.symlink?(e) }
        .sort!

      # Группировка по размеру (быстрый фильтр).
      by_size = {} of Int64 => Array(String)
      files.each do |f|
        sz = File.size(f)
        (by_size[sz] ||= [] of String) << f
      end

      candidates = by_size.select { |_, v| v.size > 1 }

      # Полный MD5 для каждого кандидата.
      dup_groups = [] of {hash: String, size: Int64, files: Array(String)}

      candidates.each do |size, group_files|
        by_hash = {} of String => Array(String)

        group_files.each do |f|
          hash = Digest::MD5.hexdigest(File.read(f))
          (by_hash[hash] ||= [] of String) << f
        end

        by_hash.each do |hash, dup_files|
          dup_groups << {hash: hash, size: size, files: dup_files} if dup_files.size > 1
        end
      end

      # Вывод результатов.
      if config.json_output
        puts dup_groups.to_json
      else
        if dup_groups.empty?
          puts "No duplicates found"
        else
          dup_groups.each do |g|
            puts "MD5: #{g[:hash]}  Size: #{g[:size]}"
            g[:files].each { |f| puts "  #{f}" }
            puts
          end
        end
      end

      # Создать .dups с hardlink-копиями.
      create_dup_links(config, path, dup_groups)
    end

    private def create_dup_links(
      config : Config,
      path : String,
      groups : Array({hash: String, size: Int64, files: Array(String)}),
    ) : Nil
      return if groups.empty? || config.dry_run

      dups_dir = "#{path}.dups"

      if Dir.exists?(dups_dir)
        STDERR.puts "Dups dir already exists: #{dups_dir}, skipping"
        return
      end

      Dir.mkdir(dups_dir)
      total_links = 0

      groups.each do |g|
        hash_dir = "#{dups_dir}/#{g[:hash]}"
        Dir.mkdir(hash_dir)

        g[:files].each do |f|
          rel = f.sub(path, "").lstrip('/')
          target = "#{hash_dir}/#{rel}"
          Dir.mkdir_p(File.dirname(target))
          File.link(f, target)
          total_links += 1
        end
      end

      STDERR.puts "Dups: #{groups.size} groups, #{total_links} hardlinks in #{dups_dir}"
    end

    private def run_apply(config : Config) : Nil
      apply_path = File.realpath(config.apply_path)

      unless Dir.exists?(apply_path)
        STDERR.puts "ERROR: apply path not found: #{apply_path}"
        exit(1)
      end

      path = File.realpath(config.path)
      unless Dir.exists?(path)
        STDERR.puts "ERROR: target path not found: #{path}"
        exit(1)
      end

      # Сканировать .dups: собрать keeper-пути по хеш-группам.
      # Структура: .dups/HASH/rel/path/file
      keepers = {} of String => Array(String)

      Dir.glob("#{apply_path}/*").each do |hash_dir|
        next unless File.directory?(hash_dir)
        hash = File.basename(hash_dir)

        Dir.glob("#{hash_dir}/**/*").each do |entry|
          next unless File.file?(entry)
          rel = entry.sub(hash_dir, "").lstrip('/')
          (keepers[hash] ||= [] of String) << rel
        end
      end

      if keepers.empty?
        puts "No keeper files found in #{apply_path}"
        return
      end

      # Предвычислить MD5 для каждой группы (по первому файлу группы).
      group_hashes = {} of String => String
      keepers.each do |hash, rels|
        next if rels.empty?
        sample = "#{apply_path}/#{hash}/#{rels.first}"
        group_hashes[hash] = Digest::MD5.hexdigest(File.read(sample)) if File.exists?(sample)
      end

      # Инвертировать: MD5 → хеш-группа.
      md5_to_group = {} of String => String
      group_hashes.each { |h, md5| md5_to_group[md5] = h }

      # Пройти по целевой папке.
      problems_dir = "#{path}.problems"
      stamp = Time.utc.to_s("%Y%m%d_%H%M%S")
      if Dir.exists?(problems_dir)
        problems_dir = "#{path}.problems.#{stamp}"
      end

      moved = 0
      kept = 0

      Dir.glob("#{path}/**/*").each do |entry|
        next unless File.file?(entry)
        rel = entry.sub(path, "").lstrip('/')

        file_md5 = Digest::MD5.hexdigest(File.read(entry))

        if group = md5_to_group[file_md5]?
          if keepers[group].includes?(rel)
            kept += 1
          else
            # Дубликат, отсутствующий в keepers → переместить в .problems.
            unless Dir.exists?(problems_dir)
              Dir.mkdir_p(problems_dir)
            end
            target = "#{problems_dir}/#{rel}"
            Dir.mkdir_p(File.dirname(target))
            File.rename(entry, target)
            moved += 1
          end
        else
          kept += 1 # Не дубликат — не трогаем.
        end
      end

      # Удалить пустые папки.
      delete_empty_dirs(path)

      STDERR.puts "Apply: kept #{kept}, moved to problems: #{moved}"
    end

    private def delete_empty_dirs(path : String) : Nil
      loop do
        deleted = false
        Dir.glob("#{path}/**/").sort!.reverse!.each do |dir|
          next unless Dir.exists?(dir)
          begin
            Dir.delete(dir)
            deleted = true
          rescue
          end
        end
        break unless deleted
      end
    end
  end
end
