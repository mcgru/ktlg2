module Ktlg2
  # Команда check. Проверяет, совпадает ли дата в имени файла с mtime.
  #
  # bash-оригинал, строки 161-183.
  module Checker
    extend self

    def run(config : Config) : Nil
      path = File.realpath(config.path)
      files = Dir.glob("#{path}/**/*")
        .select { |e| File.file?(e) && !File.symlink?(e) }
        .sort

      results = [] of NamedTuple(file: String, filename_date: String?, mtime_date: String?, match: Bool)

      files.each do |f|
        # Извлекаем дату из имени файла (только Filename, не EXIF/ФС).
        ts = Extractor.parse_filename(f)
        mtime = Extractor.filesystem_mtime(f)

        filename_date = ts ? Time.unix(ts.timestamp).to_s("%Y%m%d") : nil
        mtime_date = mtime ? Time.unix(mtime.timestamp).to_s("%Y%m%d") : nil

        match = if filename_date && mtime_date
                  filename_date == mtime_date
                else
                  false
                end

        results << {
          file: f,
          filename_date: filename_date,
          mtime_date: mtime_date,
          match: match,
        }
      end

      if config.json_output
        puts results.to_json
      else
        mismatches = results.select { |r| !r[:match] && r[:filename_date] }
        if mismatches.empty?
          puts "All files: OK"
        else
          mismatches.each do |r|
            puts "MISMATCH: #{r[:file]}  Name=#{r[:filename_date]}  File=#{r[:mtime_date]}"
          end
        end
      end
    end
  end
end
