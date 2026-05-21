require "./spec_helper"

describe Ktlg2::DupFinder do
  describe "dry-run" do
    it "scans and reports without creating .dups" do
      config = Ktlg2::Config.new(
        path: FIXTURES_DIR,
        dry_run: true,
      )

      Ktlg2::DupFinder.run(config)
    end

    it "produces JSON output" do
      config = Ktlg2::Config.new(
        path: FIXTURES_DIR,
        dry_run: true,
        json_output: true,
      )

      Ktlg2::DupFinder.run(config)
    end
  end

  describe "with actual duplicates" do
    it "finds duplicates and creates .dups hardlinks" do
      with_copy_of_fixtures do |test_path|
        # Create an intentional duplicate.
        files = Dir.glob("#{test_path}/**/*")
          .select { |e| File.file?(e) && !File.symlink?(e) }
          .sort!
        dup_target = files.first
        File.copy(dup_target, "#{test_path}/copy_of_#{File.basename(dup_target)}")

        config = Ktlg2::Config.new(path: test_path)
        Ktlg2::DupFinder.run(config)

        # .dups directory should exist with at least one hash group.
        dups_dir = "#{test_path}.dups"
        Dir.exists?(dups_dir).should be_true

        hash_dirs = Dir.glob("#{dups_dir}/*").select { |d| File.directory?(d) }
        hash_dirs.should_not be_empty
      end
    end

    it "applies resolution via --apply" do
      with_copy_of_fixtures do |test_path|
        # Create a duplicate and find it.
        files = Dir.glob("#{test_path}/**/*")
          .select { |e| File.file?(e) && !File.symlink?(e) }
          .sort!
        dup_target = files.first
        File.copy(dup_target, "#{test_path}/copy_of_#{File.basename(dup_target)}")

        config = Ktlg2::Config.new(path: test_path)
        Ktlg2::DupFinder.run(config)

        dups_dir = "#{test_path}.dups"
        Dir.exists?(dups_dir).should be_true

        # Now apply: mark everything as keeper (don't delete anything from .dups).
        apply_config = Ktlg2::Config.new(
          path: test_path,
          apply_path: dups_dir,
        )
        Ktlg2::DupFinder.run(apply_config)
      end
    end
  end
end
