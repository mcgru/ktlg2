require "./spec_helper"

describe Ktlg2::Checker do
  describe "check" do
    it "reports all files OK when dates match" do
      config = Ktlg2::Config.new(
        path: FIXTURES_DIR,
      )

      Ktlg2::Checker.run(config)
    end

    it "produces JSON output" do
      config = Ktlg2::Config.new(
        path: FIXTURES_DIR,
        json_output: true,
      )

      Ktlg2::Checker.run(config)
    end
  end
end
