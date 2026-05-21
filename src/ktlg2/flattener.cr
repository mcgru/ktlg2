module Ktlg2
  # Команда plane.
  #
  # Собирает все файлы из поддиректорий в корневую директорию.
  # Удаляет опустевшие поддиректории. Обрабатывает коллизии имён
  # через MD5-сравнение (одинаковые удаляются, разные нумеруются).
  #
  # bash-оригинал, строки 185-190:
  # `xargs mv -n -t "$P"` + `find -type d -empty -delete`
  module Flattener
    extend self

    def run(config : Config) : Nil
      path = File.realpath(config.path)
      files = Dir.glob("#{path}/**/*")
        .select { |e| File.file?(e) && !File.symlink?(e) }
        .sort!

      moved_count = 0
      collision_count = 0

      files.each do |f|
        rel = f.sub(path, "").lstrip('/')
        # Пропускаем файлы уже в корне.
        next unless rel.includes?('/')

        basename = File.basename(f)
        target = "#{path}/#{basename}"

        if config.dry_run
          puts "  #{f}  ->  #{target}"
          next
        end

        if f == target
          next
        end

        if File.exists?(target)
          # Коллизия: проверяем содержимое.
          src_md5 = md5(f)
          tgt_md5 = md5(target)

          if src_md5 == tgt_md5
            File.delete(f)
            STDERR.puts "Duplicate removed: #{f}"
          else
            stem = basename.rpartition('.').first
            ext = File.extname(basename)
            n = 1
            loop do
              new_target = "#{path}/#{stem}.(#{n})#{ext}"
              break unless File.exists?(new_target)
              n += 1
            end
            File.rename(f, "#{path}/#{stem}.(#{n})#{ext}")
            STDERR.puts "Collision: #{f} -> #{stem}.(#{n})#{ext}"
            collision_count += 1
          end
        else
          File.rename(f, target)
          moved_count += 1
        end
      end

      # Удалить пустые поддиректории.
      unless config.dry_run
        delete_empty_dirs(path)
      end

      STDERR.puts "Moved: #{moved_count}, Collisions: #{collision_count}" if config.verbose
    end

    private def md5(path : String) : String
      Digest::MD5.hexdigest(File.read(path))
    end

    private def delete_empty_dirs(path : String) : Nil
      loop do
        deleted = false
        Dir.glob("#{path}/**/").sort!.reverse!.each do |dir|
          next unless Dir.exists?(dir)
          next if dir.rstrip('/') == path
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
