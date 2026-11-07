extends Node
## The country the game is set in. Everything that differs between countries is
## read from this pack, so a new country needs no code.

signal pack_changed

const DEFAULT_PACK := "res://data/packs/colombia/pack.json"

var pack: CountryPack


func _init() -> void:
	pack = CountryPack.read(DEFAULT_PACK)


## Tests and tools use this to play another country.
func use_pack(pack_file: String) -> void:
	pack = CountryPack.read(pack_file)
	pack_changed.emit()
