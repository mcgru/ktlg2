require "spec"
require "../src/ktlg2"

# Путь к тестовым файлам.
FIXTURES_DIR  = File.join(__DIR__, "..", "tests", "src.files")
TEST_DIR_NAME = "ktlg2_spec_test"

def fixture_path(*parts)
  File.join(FIXTURES_DIR, *parts)
end

# Создать временную директорию с копией тестовых файлов.
def with_copy_of_fixtures(&)
  tmpdir = File.join(Dir.tempdir, "#{TEST_DIR_NAME}_#{Process.pid}_#{Random.rand(10000)}")
  Dir.mkdir(tmpdir)
  FileUtils.cp_r(FIXTURES_DIR, tmpdir)
  test_path = File.join(tmpdir, "src.files")
  yield test_path
ensure
  FileUtils.rm_rf(tmpdir) if tmpdir && Dir.exists?(tmpdir)
end
