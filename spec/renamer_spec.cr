require "./spec_helper"

describe Ktlg2::Renamer do
  describe ".canonical_name" do
    it "formats name with timestamp and md5 prefix" do
      file = fixture_path("160901-113748.jpg")
      name = Ktlg2::Renamer.canonical_name(file)
      name.should match(/^\d{6}-\d{6}\.[a-f0-9]{7}\.z\.jpg$/)
    end
  end

  describe "dry-run" do
    it "lists files without renaming" do
      config = Ktlg2::Config.new(
        path: FIXTURES_DIR,
        dry_run: true,
      )

      Ktlg2::Renamer.run(config)
    end
  end

  describe "full rename on copy of fixtures" do
    it "renames files to canonical format" do
      with_copy_of_fixtures do |test_path|
        config = Ktlg2::Config.new(
          path: test_path,
        )

        Ktlg2::Renamer.run(config)

        # Files should now have canonical names.
        remaining = Dir.glob("#{test_path}/**/*")
          .select { |e| File.file?(e) && !File.symlink?(e) }

        remaining.each do |f|
          basename = File.basename(f)
          basename.should match(/^\d{6}-\d{6}\.[a-f0-9]{7}\.z\.(jpg|avi)$/)
        end
      end
    end
  end
end
