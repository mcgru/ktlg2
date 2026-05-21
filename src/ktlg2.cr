# Библиотека ktlg2.
#
# Предоставляет команды для каталогизации медиафайлов:
# organize, rename, touch, plane, check, dups.
#
# Все модули подключаются здесь.
# Точка входа — `src/main.cr`.
#
# ```
# require "ktlg2"
# Ktlg2::Cli.run(["organize", "/path/to/photos"])
# ```
require "./ktlg2/*"
require "option_parser"
require "json"
require "file_utils"
require "digest/md5"
