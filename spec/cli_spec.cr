require "./spec_helper"

describe Ktlg2::Cli do
  describe ".recognize_command" do
    it "recognizes full command names" do
      Ktlg2::Cli.recognize_command("organize").should eq("organize")
      Ktlg2::Cli.recognize_command("rename").should eq("rename")
      Ktlg2::Cli.recognize_command("touch").should eq("touch")
      Ktlg2::Cli.recognize_command("plane").should eq("plane")
      Ktlg2::Cli.recognize_command("check").should eq("check")
      Ktlg2::Cli.recognize_command("dups").should eq("dups")
    end

    it "recognizes single-letter aliases" do
      Ktlg2::Cli.recognize_command("o").should eq("organize")
      Ktlg2::Cli.recognize_command("r").should eq("rename")
      Ktlg2::Cli.recognize_command("t").should eq("touch")
      Ktlg2::Cli.recognize_command("p").should eq("plane")
      Ktlg2::Cli.recognize_command("c").should eq("check")
      Ktlg2::Cli.recognize_command("d").should eq("dups")
    end

    it "recognizes three-letter aliases" do
      Ktlg2::Cli.recognize_command("org").should eq("organize")
      Ktlg2::Cli.recognize_command("ren").should eq("rename")
      Ktlg2::Cli.recognize_command("tou").should eq("touch")
      Ktlg2::Cli.recognize_command("pla").should eq("plane")
      Ktlg2::Cli.recognize_command("chk").should eq("check")
      Ktlg2::Cli.recognize_command("dup").should eq("dups")
    end

    it "returns nil for unknown commands" do
      Ktlg2::Cli.recognize_command("unknown").should be_nil
      Ktlg2::Cli.recognize_command("x").should be_nil
    end
  end

  describe ".parse_args" do
    it "defaults to organize when no command given" do
      config = Ktlg2::Cli.parse_args([FIXTURES_DIR])
      config.command.should eq("organize")
      config.path.should eq(FIXTURES_DIR)
    end

    it "recognizes organize alias" do
      config = Ktlg2::Cli.parse_args(["o", FIXTURES_DIR])
      config.command.should eq("organize")
    end

    it "parses --verbose flag" do
      config = Ktlg2::Cli.parse_args(["--verbose", FIXTURES_DIR])
      config.verbose.should be_true
    end

    it "parses --dry-run flag" do
      config = Ktlg2::Cli.parse_args(["--dry-run", FIXTURES_DIR])
      config.dry_run.should be_true
    end

    it "parses --json flag" do
      config = Ktlg2::Cli.parse_args(["--json", FIXTURES_DIR])
      config.json_output.should be_true
    end

    it "parses -j option" do
      config = Ktlg2::Cli.parse_args(["-j", "2", FIXTURES_DIR])
      config.jobs.should eq(2)
    end
  end
end
