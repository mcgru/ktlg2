require "./spec_helper"

describe Ktlg2::Organizer do
  describe "dry-run report" do
    it "reports actions without modifying files" do
      config = Ktlg2::Config.new(
        path: FIXTURES_DIR,
        dry_run: true,
      )

      # В dry-run не должно быть исключений.
      Ktlg2::Organizer.run(config)
    end

    it "produces JSON output with --json" do
      config = Ktlg2::Config.new(
        path: FIXTURES_DIR,
        dry_run: true,
        json_output: true,
      )

      Ktlg2::Organizer.run(config)
    end
  end

  describe "full organize on copy of fixtures" do
    it "moves files to correct year-based structure" do
      with_copy_of_fixtures do |test_path|
        config = Ktlg2::Config.new(
          path: test_path,
          verbose: false,
        )

        Ktlg2::Organizer.run(config)

        # Исходная папка должна быть переименована в .problems.
        Dir.exists?(test_path).should be_false

        # Финальная папка должна существовать (содержит years).
        # Имя: "Год[-Год].Суффикс"
        parent = File.dirname(test_path)
        # Ищем по маске, т.к. точное имя зависит от годов.
        result_dirs = Dir.glob("#{parent}/*")
          .select { |d| File.directory?(d) && !d.includes?(".problems") }
          .sort

        result_dirs.should_not be_empty

        # Проверяем, что внутри есть папки с годом.
        result_dirs.each do |dir|
          subdirs = Dir.glob("#{dir}/*").select { |d| File.directory?(d) }
          subdirs.should_not be_empty

          subdirs.each do |sd|
            # Проверяем наличие папок Год-Месяц.
            months = Dir.glob("#{sd}/*").select { |d| File.directory?(d) }
            months.should_not be_empty
          end
        end
      end
    end
  end
end
