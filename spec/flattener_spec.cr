require "./spec_helper"

describe Ktlg2::Flattener do
  describe "dry-run" do
    it "reports files to move without modifying" do
      config = Ktlg2::Config.new(
        path: FIXTURES_DIR,
        dry_run: true,
      )

      Ktlg2::Flattener.run(config)
    end
  end

  describe "full plane on copy of fixtures" do
    it "moves files from subdirectories to root" do
      with_copy_of_fixtures do |test_path|
        config = Ktlg2::Config.new(path: test_path)
        Ktlg2::Flattener.run(config)

        # After plane, all files should be in root (no subdirectories).
        subdirs_with_files = Dir.glob("#{test_path}/**/*")
          .count { |e| File.file?(e) && File.dirname(e) != test_path }

        subdirs_with_files.should eq(0)
      end
    end
  end
end
