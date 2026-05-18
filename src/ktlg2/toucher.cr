module Ktlg2
  # Команда touch. Выставляет mtime файла из даты, полученной из метаданных.
  #
  # Не использует filesystem как источник (чтобы не было круговой логики).
  # bash-оригинал, строки 122-156.
  module Toucher
    extend self

    def run(config : Config) : Nil
      path = File.realpath(config.path)
      files = Dir.glob("#{path}/**/*")
        .select { |e| File.file?(e) && !File.symlink?(e) }
        .sort

      touched_count = 0
      skipped_count = 0
      results = [] of {file: String, timestamp: Int64?, source: String}

      files.each do |f|
        # use_filesystem: false — чтобы не было круговой логики.
        ts = Extractor.extract_timestamp(f, use_filesystem: false)

        if ts
          results << {file: f, timestamp: ts.timestamp, source: ts.source.to_s}
          unless config.dry_run
            File.touch(f, Time.unix(ts.timestamp))
            touched_count += 1
          end
        else
          results << {file: f, timestamp: nil, source: "none"}
          skipped_count += 1
        end
      end

      if config.json_output
        puts results.to_json
      elsif config.dry_run
        results.each do |r|
          ts = r[:timestamp]
          if ts
            puts "#{Time.unix(ts)} (#{r[:source]})  #{r[:file]}"
          else
            puts "NO TIMESTAMP  #{r[:file]}"
          end
        end
      end

      STDERR.puts "Touched: #{touched_count}, Skipped: #{skipped_count}" if config.verbose
    end
  end
end
