module Ktlg2
  # Команда rename.
  #
  # Переименовывает файлы в канонический формат:
  # `YYMMDD-HHMMSS.XXXXXXX.z.ext`
  #
  # Где `XXXXXXX` — первые 7 символов MD5 первых 25600 байт.
  # Дата извлекается через `Extractor`, при отсутствии — из mtime.
  #
  # bash-оригинал, строки 134-202.
  module Renamer
    extend self

    MD5_BYTES = 25_600
    MD5_CHARS =      7

    def run(config : Config) : Nil
      path = File.realpath(config.path)
      files = Dir.glob("#{path}/**/*")
        .select { |e| File.file?(e) && !File.symlink?(e) }
        .sort!

      if config.dry_run
        files.each do |f|
          new_name = canonical_name(f)
          puts "#{f}  ->  #{new_name}" unless config.json_output
        end

        if config.json_output
          result = files.map do |f|
            {file: f, new_name: canonical_name(f)}
          end
          puts result.to_json
        end
        return
      end

      renamed_count = 0
      files.each do |f|
        dir = File.dirname(f)
        basename = File.basename(f)
        new_name = canonical_name(f)

        if basename != new_name
          target = "#{dir}/#{new_name}"
          if File.exists?(target)
            STDERR.puts "WARNING: target exists, skipping: #{f} -> #{target}"
          else
            File.rename(f, target)
            STDERR.puts "#{f} renamed to #{new_name}"
            renamed_count += 1
          end
        end
      end

      STDERR.puts "Renamed #{renamed_count} files"
    end

    # Сформировать каноническое имя файла.
    def canonical_name(path : String) : String
      ext = File.extname(path)

      ts = Extractor.extract_timestamp(path)
      if ts
        formatted = Time.unix(ts.timestamp).to_s("%y%m%d-%H%M%S")
      else
        # Если дату не удалось определить — используем mtime.
        mtime = File.info(path).modification_time
        formatted = mtime.to_s("%y%m%d-%H%M%S")
      end

      md5_prefix = md5_first_bytes(path)
      "#{formatted}.#{md5_prefix}.z#{ext}"
    end

    private def md5_first_bytes(path : String) : String
      slice = Bytes.new(MD5_BYTES)
      bytes_read = File.open(path) { |f| f.read(slice) }
      Digest::MD5.hexdigest(slice[0, bytes_read])[0, MD5_CHARS]
    end
  end
end
