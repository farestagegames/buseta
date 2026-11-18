class_name DriverEditor
extends Control
## The custom driver editor: a full cartoon page with tabs for the face, hair,
## shirt, hat and extras, locks that say how to get each part, and a small shop.

signal closed
signal changed

var slot: int = 0


func _init(editor_slot: int = 0) -> void:
	slot = editor_slot
	name = "DriverEditor"
	set_anchors_preset(Control.PRESET_FULL_RECT)
