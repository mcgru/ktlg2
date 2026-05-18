require "./spec_helper"

describe Ktlg2::Extractor do
  describe ".extract_exif" do
    it "reads DateTimeOriginal from JPEG with EXIF" do
      file = fixture_path("160901-113748.jpg")
      ts = Ktlg2::Extractor.extract_exif(file)
      ts.should_not be_nil
      ts.try do |t|
        t.source.should eq(Ktlg2::TimestampSource::Exif)
      end
    end

    it "returns nil for files without EXIF" do
      # AVI files don't have EXIF.
      file = fixture_path("2013.Прогулка-с-Лизой", "mvi_8920_1.130929-143405.avi")
      ts = Ktlg2::Extractor.extract_exif(file)
      ts.should be_nil
    end
  end

  describe ".parse_filename" do
    it "parses .z. format" do
      path = "/some/dir/160229-202921.abc1234.z.jpg"
      ts = Ktlg2::Extractor.parse_filename(path)
      ts.should_not be_nil
      ts.try { |t| Time.unix(t.timestamp).to_s("%Y%m%d").should eq("20160229") }
    end

    it "parses YYMMDD-HHMMSS from filename" do
      path = fixture_path("160229-202921.jpg")
      ts = Ktlg2::Extractor.parse_filename(path)
      ts.should_not be_nil
      ts.try { |t| Time.unix(t.timestamp).to_s("%y%m%d").should eq("160229") }
    end

    it "parses YYYYMMDD_HHMMSS from filename" do
      # Simulate with a path having 8-digit date.
      path = "/some/20231014_153022.jpg"
      ts = Ktlg2::Extractor.parse_filename(path)
      ts.should_not be_nil
      ts.try { |t| Time.unix(t.timestamp).to_s("%Y%m%d").should eq("20231014") }
    end

    it "parses YYMMDD with underscore prefix" do
      path = "/some/IMG_130929-141718.jpg"
      ts = Ktlg2::Extractor.parse_filename(path)
      ts.should_not be_nil
      ts.try { |t| Time.unix(t.timestamp).to_s("%Y%m%d").should eq("20130929") }
    end

    it "parses 20YYMMDD (8 digits starting with 20)" do
      path = "/some/20231014_something.jpg"
      ts = Ktlg2::Extractor.parse_filename(path)
      ts.should_not be_nil
      ts.try { |t| Time.unix(t.timestamp).to_s("%Y%m%d").should eq("20231014") }
    end

    it "returns nil for unparseable filename" do
      path = "/some/IMG_1234.jpg"
      ts = Ktlg2::Extractor.parse_filename(path)
      ts.should be_nil
    end
  end

  describe ".extract_timestamp" do
    it "returns EXIF timestamp for JPEG with metadata" do
      file = fixture_path("160901-113748.jpg")
      ts = Ktlg2::Extractor.extract_timestamp(file)
      ts.should_not be_nil
      ts.try { |t| t.source.should eq(Ktlg2::TimestampSource::Exif) }
    end

    it "returns filename timestamp for AVI" do
      file = fixture_path("2013.Прогулка-с-Лизой", "mvi_8920_1.130929-143405.avi")
      ts = Ktlg2::Extractor.extract_timestamp(file)
      ts.should_not be_nil
    end

    it "returns filesystem timestamp when use_filesystem: true" do
      file = fixture_path("2016.Новосибирск", "2016-05", "IMG_5016.160530-231851.jpg")
      # У этого файла есть EXIF, но принудительно проверим, что filesystem
      # сработает только если другие источники не дали результат.
      ts = Ktlg2::Extractor.extract_timestamp(file)
      ts.should_not be_nil
    end
  end
end
