class_name UiTextScaler
extends RefCounted
## Scales the text of a menu with the window height (used by the pause menu). `add()` reads a Label's or
## Button's font size and letter spacing from its Theme (written for a 1080 px high window, plus any
## override set on the node in the scene); `apply(s)` sets them to that size times `s`. The Theme's
## FontVariation is duplicated per control so its spacing can follow the window without changing the
## shared Theme resource.

class Entry extends RefCounted:
	var size_px: int = 0
	var spacing: int = 0
	var scaled: FontVariation

var _entries: Dictionary = {}


func add(control: Control) -> void:
	var entry := Entry.new()
	entry.size_px = control.get_theme_font_size(&"font_size")
	var variation := control.get_theme_font(&"font") as FontVariation
	if variation != null:
		entry.spacing = variation.spacing_glyph
		entry.scaled = variation.duplicate() as FontVariation
		control.add_theme_font_override(&"font", entry.scaled)
	_entries[control] = entry


## `s` is the window height divided by 1080.
func apply(s: float) -> void:
	for control: Control in _entries:
		var entry: Entry = _entries[control]
		control.add_theme_font_size_override(&"font_size", maxi(1, roundi(float(entry.size_px) * s)))
		if entry.scaled != null:
			entry.scaled.spacing_glyph = roundi(float(entry.spacing) * s)
