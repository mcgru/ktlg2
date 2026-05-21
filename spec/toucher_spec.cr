require "./spec_helper"

describe Ktlg2::Toucher do
  describe "dry-run" do
    it "reports timestamps without modifying files" do
      config = Ktlg2::Config.new(
        path: FIXTURES_DIR,
        dry_run: true,
      )

      Ktlg2::Toucher.run(config)
    end

    it "produces JSON output with --json" do
      config = Ktlg2::Config.new(
        path: FIXTURES_DIR,
        dry_run: true,
        json_output: true,
      )

      Ktlg2::Toucher.run(config)
    end
  end
end
