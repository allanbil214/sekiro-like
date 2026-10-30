class_name ReachArms
extends Node3D
## Debug stand-in for the mid-air reach animation: two arms snap up and forward, hold
## briefly, then drop. Builds its own boxes. Place under Visual so it turns with the body.

@export var shoulder_height: float = 1.4
@export var shoulder_offset: float = 0.45
@export var arm_length: float = 0.5
@export var raise_time: float = 0.08
@export var hold_time: float = 0.15
@export var lower_time: float = 0.12
@export var raised_angle_deg: float = 140.0
## Pose angle while sliding: 90 = arms straight forward.
@export var slide_angle_deg: float = 90.0
## Pose angle while climbing a ledge: 180 = arms straight up.
@export var climb_angle_deg: float = 180.0
@export var color: Color = Color(1.0, 0.6, 0.15)
## Item 10, the choke pose: how far forward the arms point (90 = straight ahead), how close (m) to the middle
## they close in, and the size (degrees) and speed (per second) of the squeeze.
@export var choke_angle_deg: float = 85.0
@export var choke_arm_offset: float = 0.16
@export var choke_pulse_degrees: float = 6.0
@export var choke_pulse_speed: float = 26.0

var _pivots: Array[Node3D] = []
## Phase 3a-3b-2: the boxes, hidden while the player's figure draws its own arms.
var _boxes: Array[MeshInstance3D] = []
var _boxes_hidden: bool = false
var _tween: Tween
var _angle_deg: float = 140.0
var _amount: float = 0.0
## The choke (item 10): the arms reach forward and close in, then squeeze in a small pulse.
var _choking: bool = false
var _choke_clock: float = 0.0


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * shoulder_offset, shoulder_height, 0.0)
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.1, arm_length, 0.1)
		box.mesh = mesh
		box.material_override = material
		box.position = Vector3(0.0, -arm_length * 0.5, 0.0)
		box.visible = not _boxes_hidden
		_boxes.append(box)
		pivot.add_child(box)
		add_child(pivot)
		_pivots.append(pivot)
	visible = false


## Phase 3a-3b-2: hide the box arms while the figure has arms.
func set_boxes_hidden(hidden_now: bool) -> void:
	_boxes_hidden = hidden_now
	for box in _boxes:
		box.visible = not hidden_now


## Phase 3a-3b-2: where arm `index` (0 = left, 1 = right) ends, in the world. Meaningful while this node is visible.
func get_hand_global(index: int) -> Vector3:
	return _pivots[index].to_global(Vector3(0.0, -arm_length, 0.0))


func play() -> void:
	if _tween != null:
		_tween.kill()
	_angle_deg = raised_angle_deg
	_set_shoulder_height(shoulder_height)
	visible = true
	_tween = create_tween()
	_tween.tween_method(_set_pose, 0.0, 1.0, raise_time)
	_tween.tween_interval(hold_time)
	_tween.tween_method(_set_pose, 1.0, 0.0, lower_time)
	_tween.tween_callback(func() -> void: visible = false)


## 3c-5: raise the arms to the reach pose (raised_angle_deg) and keep them there until release() (`interact` held in the air).
func hold_reach() -> void:
	_hold(raised_angle_deg, shoulder_height)


## Swing the arms forward (slide_angle_deg) and keep them there until release().
func hold_forward(shoulder_y: float) -> void:
	_hold(slide_angle_deg, shoulder_y)


## Item 10: reach forward and close in around a head at `shoulder_y`, squeezing until release().
func hold_choke(shoulder_y: float) -> void:
	_hold(choke_angle_deg, shoulder_y)
	_choking = true
	_choke_clock = 0.0
	for i in _pivots.size():
		var side := -1.0 if i == 0 else 1.0
		_pivots[i].position.x = side * choke_arm_offset


func _process(delta: float) -> void:
	if not _choking:
		return
	_choke_clock += delta
	var squeeze := 1.0 + deg_to_rad(choke_pulse_degrees) / deg_to_rad(maxf(choke_angle_deg, 1.0)) \
			* sin(_choke_clock * choke_pulse_speed)
	for pivot in _pivots:
		pivot.rotation.x = deg_to_rad(_angle_deg) * _amount * squeeze


## Swing the arms straight up (climb_angle_deg) and keep them there until release().
func hold_up() -> void:
	_hold(climb_angle_deg, shoulder_height)


func _hold(angle_deg: float, shoulder_y: float) -> void:
	if _tween != null:
		_tween.kill()
	_angle_deg = angle_deg
	_set_shoulder_height(shoulder_y)
	visible = true
	_tween = create_tween()
	_tween.tween_method(_set_pose, _amount, 1.0, raise_time)


## Item 13c: a quick jolt of the held arms (a hit while hanging): they dip and come back.
func jolt() -> void:
	if not visible:
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_pose, _amount, 0.75, 0.05)
	_tween.tween_method(_set_pose, 0.75, 1.0, 0.15)


## Lower the arms and hide them.
func release() -> void:
	if _choking:
		_choking = false
		for i in _pivots.size():
			_pivots[i].position.x = (-1.0 if i == 0 else 1.0) * shoulder_offset
	if not visible:
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_pose, _amount, 0.0, lower_time)
	_tween.tween_callback(func() -> void: visible = false)


func _set_shoulder_height(y: float) -> void:
	for pivot in _pivots:
		pivot.position.y = y


func _set_pose(amount: float) -> void:
	_amount = amount
	for pivot in _pivots:
		pivot.rotation.x = deg_to_rad(_angle_deg) * amount
