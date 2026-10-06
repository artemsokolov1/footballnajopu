extends Camera3D
## Камера сверху под углом: плавно следует за целью, не вращается вместе с ней
## и смещается вперёд по ходу движения, чтобы было видно пространство впереди.

@export var target: Node3D
## Смещение камеры от точки фокуса (задаёт и угол обзора).
@export var offset := Vector3(0.0, 8.5, 9.0)
## Постоянный сдвиг фокуса вперёд (вверх по экрану), м.
@export var forward_bias := 1.5
## Сдвиг фокуса по направлению бега на полной скорости, м.
@export var look_ahead := 3.0
## Ориентир скорости для расчёта сдвига, м/с.
@export var look_ahead_speed := 8.0
## Плавность следования (больше — жёстче).
@export var follow_sharpness := 5.0
## Плавность изменения сдвига вперёд.
@export var look_ahead_sharpness := 2.0

var _focus := Vector3.ZERO
var _ahead := Vector3.ZERO


func _ready() -> void:
	global_basis = Basis.looking_at(-offset, Vector3.UP)
	if target:
		_focus = _desired_focus()
		global_position = _focus + offset


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var vel := Vector3.ZERO
	if target is CharacterBody3D:
		vel = (target as CharacterBody3D).velocity
	vel.y = 0.0
	var ahead_target := vel / look_ahead_speed * look_ahead
	_ahead = _ahead.lerp(ahead_target, 1.0 - exp(-look_ahead_sharpness * delta))
	_focus = _focus.lerp(_desired_focus(), 1.0 - exp(-follow_sharpness * delta))
	global_position = _focus + offset


func _desired_focus() -> Vector3:
	var fwd := Vector3(-global_basis.z.x, 0.0, -global_basis.z.z).normalized()
	return Vector3(target.global_position.x, 0.0, target.global_position.z) + fwd * forward_bias + _ahead
