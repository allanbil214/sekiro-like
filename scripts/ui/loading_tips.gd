class_name LoadingTips
extends RefCounted
## The loading-screen tips (Phase 2, item 5), read from a CSV the user edits (`data/loading_tips.csv`).
## Columns: id, context, title, text (any order, the header row names them). `context` is `any` or an
## arena category (`fighting`, `movement`, `test`). A tip is shown only where its context is `any` or
## matches the arena being loaded. Tips come in shuffled order and none repeats until all were shown.

class Tip extends RefCounted:
	var id: String = ""
	var context: String = "any"
	var title: String = ""
	var text: String = ""

var _all: Array[Tip] = []
var _bag: Array[Tip] = []
var _pool_size: int = 0
var _last: Tip = null


## Read the file and keep the tips that fit `context`. Logs a warning and stays empty if the file is missing.
func load_file(path: String, context: String) -> void:
	_all.clear()
	_bag.clear()
	_last = null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("LoadingTips: cannot open %s (error %d)." % [path, FileAccess.get_open_error()])
		return
	var header := file.get_csv_line()
	if header.size() > 0:
		# Excel's "CSV UTF-8" starts the file with a byte order mark.
		header[0] = header[0].trim_prefix("\ufeff")
	var columns: Dictionary = {}
	for index: int in header.size():
		columns[header[index].strip_edges().to_lower()] = index
	if not columns.has("text"):
		push_warning("LoadingTips: %s has no \"text\" column." % path)
		return
	while not file.eof_reached():
		var row := file.get_csv_line()
		var text := _cell(row, columns, "text")
		if text.is_empty():
			continue
		var tip := Tip.new()
		tip.id = _cell(row, columns, "id")
		tip.context = _cell(row, columns, "context").to_lower()
		if tip.context.is_empty():
			tip.context = "any"
		tip.title = _cell(row, columns, "title")
		tip.text = text
		if tip.context == "any" or tip.context == context.to_lower():
			_all.append(tip)
	_pool_size = _all.size()


func is_empty() -> bool:
	return _all.is_empty()


## The next tip: a shuffled round with no repeats, and the same tip never twice in a row across rounds.
func next() -> Tip:
	if _all.is_empty():
		return null
	if _bag.is_empty():
		_bag = _all.duplicate()
		_bag.shuffle()
		# pop_back() takes the last one: make sure it is not the tip that was just shown.
		if _pool_size > 1 and _bag.back() == _last:
			var swap_with := randi_range(0, _bag.size() - 2)
			var held: Tip = _bag[swap_with]
			_bag[swap_with] = _bag.back()
			_bag[_bag.size() - 1] = held
	_last = _bag.pop_back()
	return _last


static func _cell(row: PackedStringArray, columns: Dictionary, column: String) -> String:
	if not columns.has(column):
		return ""
	var index: int = columns[column]
	if index >= row.size():
		return ""
	return row[index].strip_edges()
