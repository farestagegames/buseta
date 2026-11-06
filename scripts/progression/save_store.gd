class_name SaveStore
extends RefCounted
## Reads and writes the save file safely. A write goes to a temporary file first
## and replaces the old save only when complete, and the previous good save is
## kept as a backup, so a crash or dead battery can never lose progress.

const TEMP_SUFFIX := ".tmp"
const BACKUP_SUFFIX := ".bak"


static func write(path: String, data: Dictionary) -> bool:
	var temp := path + TEMP_SUFFIX
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	var written := file.get_error() == OK
	file.close()
	if not written or read_file(temp).is_empty():
		DirAccess.remove_absolute(temp)
		return false
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path + BACKUP_SUFFIX)
		DirAccess.rename_absolute(path, path + BACKUP_SUFFIX)
	return DirAccess.rename_absolute(temp, path) == OK


## Returns the saved data, falling back to the backup, or empty if neither reads.
static func read(path: String) -> Dictionary:
	var main := read_file(path)
	if not main.is_empty():
		return main
	return read_file(path + BACKUP_SUFFIX)


static func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return parser.data if parser.data is Dictionary else {}
