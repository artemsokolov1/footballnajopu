class_name Player
extends Footballer
## Игрок под управлением человека: бег относительно камеры, удар с набором силы,
## пас напарнику и возврат мяча.

## Сила удара 0..1 и идёт ли набор (для шкалы).
signal charge_changed(power: float, charging: bool)

## Кому пасовать.
@export var teammate: Footballer

@export_group("Kick")
## Время удержания удара для максимальной силы, с.
@export var max_charge_time := 0.8

@export_group("Pass")
## Половина угла сектора, в котором пас уходит точно в напарника, градусы.
@export var pass_assist_angle := 45.0

var _charging := false
var _charge_time := 0.0


func _physics_process(delta: float) -> void:
	var accel := _move(delta, _input_direction(), Input.is_action_pressed("sprint"))
	_update_ball_contact(delta)
	_update_kick(delta)
	if Input.is_action_just_pressed("pass"):
		_pass()
	if Input.is_action_just_pressed("reset_ball"):
		_reset_ball()
	_animate(delta, accel, _charge_power() if _charging else -1.0)


func _input_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_fwd := Vector3.FORWARD
	var cam_right := Vector3.RIGHT
	var cam := get_viewport().get_camera_3d()
	if cam:
		cam_fwd = Vector3(-cam.global_basis.z.x, 0.0, -cam.global_basis.z.z).normalized()
		cam_right = Vector3(cam.global_basis.x.x, 0.0, cam.global_basis.x.z).normalized()
	return cam_right * input.x - cam_fwd * input.y


func _charge_power() -> float:
	return clampf(_charge_time / max_charge_time, 0.0, 1.0)


func _update_kick(delta: float) -> void:
	if Input.is_action_just_pressed("kick"):
		_charging = true
		_charge_time = 0.0
	if not _charging:
		return
	_charge_time = minf(_charge_time + delta, max_charge_time)
	if Input.is_action_pressed("kick"):
		charge_changed.emit(_charge_power(), true)
		return
	_charging = false
	var power := _charge_power()
	charge_changed.emit(power, false)
	_kick(power)


## Пас в напарника, если он примерно впереди; иначе — по направлению корпуса.
func _pass() -> void:
	if _charging:
		_charging = false
		charge_changed.emit(0.0, false)
	var target := global_position + forward() * free_pass_distance
	if teammate:
		var to_mate := teammate.global_position - global_position
		to_mate.y = 0.0
		if to_mate.length() > 1.0 and rad_to_deg(forward().angle_to(to_mate)) <= pass_assist_angle:
			# Упреждение: пас туда, где напарник будет к приходу мяча.
			var travel := to_mate.length() / 9.0
			target = teammate.global_position + teammate.flat_velocity() * minf(travel, 1.0)
	_pass_to(target)


func _reset_ball() -> void:
	if ball == null:
		return
	var target := global_position + forward() * control_distance
	target.y = ball.radius + 0.02
	# Не ставим мяч за забор или в стойку ворот.
	var from := global_position + Vector3.UP * target.y
	var query := PhysicsRayQueryParameters3D.create(from, target + forward() * ball.radius, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		target = hit.position - forward() * (ball.radius + 0.05)
		target.y = ball.radius + 0.02
	ball.reset_to(target)
