module Ktlg2
  # Текущая версия ktlg2 (semver), читается из shard.yml при компиляции.
  VERSION = {{ read_file("./shard.yml").split('\n').find(&.starts_with?("version: ")).gsub(/version: /, "").strip }}
end
