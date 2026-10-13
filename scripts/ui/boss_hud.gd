class_name BossHud
extends CanvasLayer
## The boss HUD (Phase 2, item 3c-1 addendum), drawn in code (no art files). Must be a direct child of
## Player. When a boss notices the player (an enemy with `boss` on that has left IDLE), it shows the boss's
## name, its health (the red bar with the yellow trail, and a round dot per health bar left) at the top
## left, and its posture bar at the top center (it grows from the middle out, with a chevron at each
## end), and the boss's floating bar hides (its deathblow marker stays). It reads the bosses through
## `Enemies.all()`; a boss is anything there with `is_boss_engaged()`, `get_boss_name()` and
## `set_boss_hud_shown()` (`Enemy` and `Dummy` have them).
## One boss owns the HUD at a time. The first boss to notice the player owns it. It passes to another
## engaged boss only when the player hits that boss and no other (and not the owner) with one swing or
## attack: a hit on several bosses at once, and a hit on the owner, leave it where it is. After a
## switch it ignores further switches for `switch_cooldown`. When the owner dies, stops noticing the
## player, or the player dies, it passes to the next engaged boss, or fades out. Lock-on does not switch it.
## Sized for a 1080 px high window and scaled with it.

@export_group("Layout (at a 1080 px high window)")
@export var ui_reference_height: float = 1080.0
## Distance from the top-left corner to the name block (px).
@export var margin: Vector2 = Vector2(56.0, 44.0)
@export var health_bar_size: Vector2 = Vector2(440.0, 12.0)
@export var pip_radius: float = 7.0
@export var pip_gap: float = 6.0
@export var pip_lift: float = 8.0
@export var name_font_size: int = 26
@export var name_gap: float = 10.0
## The posture bar: its size, the distance from the top edge, and the chevrons at its ends.
@export var posture_bar_size: Vector2 = Vector2(520.0, 9.0)
@export var posture_top_margin: float = 48.0
@export var chevron_size: float = 9.0
@export var chevron_gap: float = 22.0

@export_group("Behavior")
## Seconds to fade in when a boss notices the player, and to fade out when none is left.
@export var fade_in_time: float = 0.3
@export var fade_out_time: float = 0.6
## Hits on bosses within this many seconds of the first one count as one swing or attack (a hit on
## several bosses in it keeps the HUD where it is).
@export var switch_group_time: float = 0.1
## After a switch, no other switch for this many seconds.
@export var switch_cooldown: float = 1.0

@export_group("Health")
@export var health_color: Color = Color(0.78, 0.06, 0.06)
@export var yellow_color: Color = Color(0.95, 0.8, 0.15)
@export var back_color: Color = Color(0.04, 0.04, 0.04, 0.8)
@export var frame_color: Color = Color(0.55, 0.5, 0.45, 0.55)
@export var yellow_delay: float = 1.0
@export var yellow_drain_speed: float = 0.5
@export var pip_color: Color = Color(0.85, 0.08, 0.08)
@export var pip_outline_color: Color = Color(0.32, 0.02, 0.04)
@export var name_color: Color = Color(0.92, 0.9, 0.85)

@export_group("Posture bar")
@export var posture_color_low: Color = Color(1.0, 0.85, 0.1)
@export var posture_color_high: Color = Color(1.0, 0.35, 0.05)
@export_range(0.2, 4.0) var posture_color_curve: float = 1.0
@export var posture_color_full: Color = Color(0.95, 0.04, 0.04)
@export var posture_flash_color: Color = Color(1.0, 0.85, 0.8)
@export var posture_flash_time: float = 0.35
@export var posture_drain_speed: float = 1.2
@export var posture_rise_speed: float = 8.0
@export var posture_back_color: Color = Color(0.04, 0.04, 0.04, 0.45)
@export var chevron_color: Color = Color(0.85, 0.83, 0.78, 0.75)

var _player: Player
var _canvas: Control
var _font: Font
## The boss that owns the HUD (its floating bar is hidden), and the boss being drawn (the owner, or the
## last owner while the HUD fades out).
var _owner: Node3D
var _shown: Node3D
var _alpha: float = 0.0
## Engaged bosses and when each noticed the player (msec); every boss whose signals are connected.
var _noticed_at: Dictionary = {}
var _connected: Dictionary = {}
## Bosses the player hit within the current group window, and the time left of it.
var _hit_bosses: Array[Node3D] = []
var _group_left: float = 0.0
var _switch_lock: float = 0.0
var _red: float = 1.0
var _yellow: float = 1.0
var _hold: float = 0.0
var _posture_shown: float = 0.0
var _posture_was_full: bool = false
var _flash_left: float = 0.0


func _ready() -> void:
	layer = 9
	_player = get_parent() as Player
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Georgia"])
	_font = serif
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _exit_tree() -> void:
	# Leaving the scene: give the owner its floating bar back (it may outlive this node briefly).
	if _owner != null and is_instance_valid(_owner):
		_owner.call(&"set_boss_hud_shown", false)


func _process(delta: float) -> void:
	_scan_bosses()
	_switch_lock = maxf(_switch_lock - delta, 0.0)
	if _group_left > 0.0:
		_group_left -= delta
		if _group_left <= 0.0:
			_evaluate_hits()
	_update_owner()
	_update_fade(delta)
	_update_values(delta)
	_canvas.modulate.a = _alpha
	_canvas.queue_redraw()


## Find the bosses, connect their hit signals once, and note who is engaged and since when.
func _scan_bosses() -> void:
	for boss: Node3D in Enemies.all():
		if not boss.has_method(&"is_boss_engaged"):
			continue
		_connect_boss(boss)
		if boss.call(&"is_boss_engaged"):
			if not _noticed_at.has(boss):
				_noticed_at[boss] = Time.get_ticks_msec()
		else:
			_noticed_at.erase(boss)
	for known: Variant in _noticed_at.keys():
		if not is_instance_valid(known):
			_noticed_at.erase(known)


func _connect_boss(boss: Node3D) -> void:
	if _connected.has(boss):
		return
	_connected[boss] = true
	var combatant := Combatant.of(boss)
	if combatant == null:
		return
	combatant.damaged.connect(_on_boss_damaged.bind(boss))
	combatant.hit_guarded.connect(_on_boss_guarded.bind(boss))
	combatant.hit_deflected.connect(_on_boss_deflected.bind(boss))


func _on_boss_damaged(hit: HitData, _amount: float, boss: Node3D) -> void:
	_register_hit(hit, boss)


func _on_boss_guarded(hit: HitData, _chip: float, boss: Node3D) -> void:
	_register_hit(hit, boss)


func _on_boss_deflected(hit: HitData, boss: Node3D) -> void:
	_register_hit(hit, boss)


## The player hit (or was blocked by) a boss: collect it for the group window.
func _register_hit(hit: HitData, boss: Node3D) -> void:
	if hit.attacker != _player:
		return
	if _hit_bosses.is_empty():
		_group_left = switch_group_time
	if not _hit_bosses.has(boss):
		_hit_bosses.append(boss)


## The group window ended: switch only if exactly one boss was hit, it is not the owner, and it is engaged.
func _evaluate_hits() -> void:
	var hit_bosses := _hit_bosses.duplicate()
	_hit_bosses.clear()
	if _owner == null or _switch_lock > 0.0 or hit_bosses.size() != 1:
		return
	var target: Node3D = hit_bosses[0]
	if target == _owner or not is_instance_valid(target) or not _noticed_at.has(target):
		return
	_set_owner(target)
	_switch_lock = switch_cooldown


## Release an owner that is gone or no longer engaged, and give the HUD to the boss that noticed first.
func _update_owner() -> void:
	if _owner != null and (not is_instance_valid(_owner) or not _noticed_at.has(_owner)):
		if is_instance_valid(_owner):
			_owner.call(&"set_boss_hud_shown", false)
		_owner = null
	if _owner != null:
		return
	var best: Node3D = null
	var best_time: int = 0
	for boss: Node3D in _noticed_at:
		var since: int = _noticed_at[boss]
		if best == null or since < best_time:
			best = boss
			best_time = since
	if best != null:
		_set_owner(best)


func _set_owner(boss: Node3D) -> void:
	if boss == _owner:
		return
	if _owner != null and is_instance_valid(_owner):
		_owner.call(&"set_boss_hud_shown", false)
	_owner = boss
	_shown = boss
	boss.call(&"set_boss_hud_shown", true)
	_sync_values(boss)


## Start the drawn values from the boss's real ones (no trail from the previous boss).
func _sync_values(boss: Node3D) -> void:
	var combatant := Combatant.of(boss)
	if combatant == null:
		return
	_red = combatant.health / maxf(combatant.max_health, 0.001)
	_yellow = _red
	_hold = 0.0
	_posture_shown = clampf(combatant.posture / maxf(combatant.max_posture, 0.001), 0.0, 1.0)
	_posture_was_full = combatant.posture_full
	_flash_left = 0.0


func _update_fade(delta: float) -> void:
	if _shown != null and not is_instance_valid(_shown):
		_shown = null
		_alpha = 0.0
	if _owner != null:
		_alpha = minf(_alpha + delta / maxf(fade_in_time, 0.01), 1.0)
		return
	_alpha = maxf(_alpha - delta / maxf(fade_out_time, 0.01), 0.0)
	if _alpha <= 0.0:
		_shown = null


## Ease the drawn health trail and posture toward the boss's real values.
func _update_values(delta: float) -> void:
	if _shown == null:
		return
	var combatant := Combatant.of(_shown)
	if combatant == null:
		return
	var health_fraction := combatant.health / maxf(combatant.max_health, 0.001)
	if health_fraction < _red - 0.0001:
		_hold = yellow_delay
	elif health_fraction > _red + 0.0001:
		_yellow = health_fraction
	_red = health_fraction
	if _hold > 0.0:
		_hold -= delta
	elif _yellow > _red:
		_yellow = maxf(_red, _yellow - yellow_drain_speed * delta)
	var target := clampf(combatant.posture / maxf(combatant.max_posture, 0.001), 0.0, 1.0)
	var full := combatant.posture_full
	if full and not _posture_was_full:
		_posture_shown = 1.0
		_flash_left = posture_flash_time
	_posture_was_full = full
	if _posture_shown < target:
		_posture_shown = minf(_posture_shown + posture_rise_speed * delta, target)
	elif _posture_shown > target and not full:
		_posture_shown = maxf(_posture_shown - posture_drain_speed * delta, target)
	if _flash_left > 0.0:
		_flash_left -= delta


func _draw_hud() -> void:
	if _shown == null or _alpha <= 0.003:
		return
	var combatant := Combatant.of(_shown)
	if combatant == null:
		return
	var size := _canvas.size
	var s := size.y / maxf(ui_reference_height, 1.0)
	_draw_health(combatant, s)
	_draw_posture(combatant, size, s)


## Top left: the dots, the health bar, and the name below it.
func _draw_health(combatant: Combatant, s: float) -> void:
	var x0 := margin.x * s
	var y := margin.y * s
	var radius := pip_radius * s
	if combatant.health_bars >= 2:
		for i in combatant.bars_left:
			var center := Vector2(x0 + radius + float(i) * (radius * 2.0 + pip_gap * s), y + radius)
			_canvas.draw_circle(center, radius, pip_outline_color)
			_canvas.draw_circle(center, radius * 0.72, pip_color)
		y += radius * 2.0 + pip_lift * s
	var bar_w := health_bar_size.x * s
	var bar_h := health_bar_size.y * s
	var back := Rect2(x0 - 2.0 * s, y - 2.0 * s, bar_w + 4.0 * s, bar_h + 4.0 * s)
	_canvas.draw_rect(back, back_color)
	_canvas.draw_rect(Rect2(x0, y, bar_w * clampf(_yellow, 0.0, 1.0), bar_h), yellow_color)
	_canvas.draw_rect(Rect2(x0, y, bar_w * clampf(_red, 0.0, 1.0), bar_h), health_color)
	_canvas.draw_rect(back, frame_color, false, maxf(1.0, s))
	var font_px := int(round(float(name_font_size) * s))
	var text_pos := Vector2(x0, y + bar_h + name_gap * s + float(font_px) * 0.8)
	var text: String = _shown.call(&"get_boss_name")
	_canvas.draw_string(_font, text_pos + Vector2(1.5, 1.5) * s, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_px, Color(0.0, 0.0, 0.0, 0.8))
	_canvas.draw_string(_font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_px, name_color)


## Top center: the posture bar growing from the middle out, with a chevron at each end.
func _draw_posture(combatant: Combatant, size: Vector2, s: float) -> void:
	var width := posture_bar_size.x * s
	var height := posture_bar_size.y * s
	var center_x := size.x * 0.5
	var y := posture_top_margin * s
	_canvas.draw_rect(Rect2(center_x - width * 0.5, y, width, height), posture_back_color)
	var color := EnemyBar.posture_gradient(_posture_shown, posture_color_low, posture_color_high, posture_color_curve)
	if combatant.posture_full and _posture_shown >= 0.999:
		color = posture_color_full
		if _flash_left > 0.0 and int(_flash_left * 20.0) % 2 == 0:
			color = posture_flash_color
	var half := width * 0.5 * _posture_shown
	if half > 0.5:
		_canvas.draw_rect(Rect2(center_x - half, y, half * 2.0, height), color)
	# A thin tick at the middle, where it grows from.
	_canvas.draw_rect(Rect2(center_x - maxf(1.0, s), y - 2.0 * s, maxf(2.0, 2.0 * s), height + 4.0 * s), Color(1.0, 1.0, 1.0, 0.7))
	# A chevron at each end, pointing outward.
	var arm := chevron_size * s
	var mid_y := y + height * 0.5
	for side: float in [-1.0, 1.0]:
		var tip_x := center_x + side * (width * 0.5 + chevron_gap * s + arm)
		_canvas.draw_polyline(PackedVector2Array([
			Vector2(tip_x - side * arm, mid_y - arm),
			Vector2(tip_x, mid_y),
			Vector2(tip_x - side * arm, mid_y + arm),
		]), chevron_color, maxf(1.5, 2.0 * s), true)
