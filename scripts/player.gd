class_name Player
extends CharacterBody3D
## Игрок: бег относительно камеры, ведение мяча касаниями и удар с набором силы.
## С мячом физически не сталкивается — все воздействия на мяч идут только через
## ball.touch() и ball.kick(), поэтому двойного импульса не бывает.

## Сила удара 0..1 и идёт ли набор (для шкалы).
signal charge_changed(power: float, charging: bool)

@export var ball: Ball

@export_group("Movement")
## Скорость обычного бега, м/с.
@export var run_speed := 5.5
## Скорость с ускорением (Shift / RT), м/с.
@export var sprint_speed := 8.0
## Разгон, м/с².
@export var acceleration := 26.0
## Торможение и гашение бокового скольжения, м/с².
@export var deceleration := 45.0
## Скорость поворота корпуса к направлению движения.
@export var turn_speed := 14.0
@export var gravity := 20.0

@export_group("Dribble")
## Горизонтальное расстояние центр–центр, на котором игрок касается мяча, м.
@export var touch_radius := 0.5
## Выше этой высоты центра мяча касаний нет, м.
@export var touch_height := 1.7
## Скорость мяча после касания относительно скорости игрока.
@export var dribble_push := 1.4
## Минимальная скорость, с которой мяч отходит от игрока после касания, м/с.
@export var dribble_min_push := 0.6
## Насколько касание направляет мяч по ходу игрока (0 — чистая физика, 1 — строго по ходу).
@export_range(0.0, 1.0) var dribble_steer := 0.35

@export_group("Kick")
## Дальность удара: максимальное горизонтальное расстояние до центра мяча, м.
@export var kick_reach := 1.1
## Половина угла сектора перед игроком, в котором мяч можно ударить, градусы.
@export var kick_angle := 65.0
## Время удержания для максимальной силы, с.
@export var max_charge_time := 0.8
## Скорость мяча при коротком нажатии, м/с.
@export var min_kick_speed := 7.0
## Скорость мяча при полном наборе, м/с.
@export var max_kick_speed := 24.0
## Угол подъёма мяча при полной силе, градусы.
@export var max_lift_angle := 12.0
## С какой силы (0..1) мяч начинает подниматься.
@export_range(0.0, 1.0) var lift_start := 0.5
## Доля скорости бега, добавляемая к удару.
@export var run_kick_bonus := 0.3
## Пауза после удара, когда касания отключены, с.
@export var kick_cooldown := 0.3

var _charging := false
var _charge_time := 0.0
var _cooldown := 0.0

@onready var _model := $Model
@onready var _kick_sound: AudioStreamPlayer3D = $KickSound


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var accel := _update_movement(delta)
	_update_kick(delta)
	_update_ball_touch()
	if Input.is_action_just_pressed("reset_ball"):
		_reset_ball()
	var flat_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var charge := _charge_power() if _charging else -1.0
	_model.update_pose(delta, flat_speed, run_speed, charge, accel)


func forward() -> Vector3:
	return -global_basis.z


## Возвращает продольное ускорение (для наклона модели).
func _update_movement(delta: float) -> float:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_fwd := Vector3.FORWARD
	var cam_right := Vector3.RIGHT
	var cam := get_viewport().get_camera_3d()
	if cam:
		cam_fwd = Vector3(-cam.global_basis.z.x, 0.0, -cam.global_basis.z.z).normalized()
		cam_right = Vector3(cam.global_basis.x.x, 0.0, cam.global_basis.x.z).normalized()
	var dir := cam_right * input.x - cam_fwd * input.y

	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var old_flat := flat
	if dir.length_squared() < 0.0001:
		flat = flat.move_toward(Vector3.ZERO, deceleration * delta)
	else:
		var max_speed := sprint_speed if Input.is_action_pressed("sprint") else run_speed
		var d := dir.normalized()
		var target_speed := max_speed * minf(dir.length(), 1.0)
		var along := flat.dot(d)
		var side := flat - d * along
		# Разворот гасим быстро, разгон и сброс скорости после спринта — плавно.
		var rate := deceleration if along < 0.0 else acceleration
		along = move_toward(along, target_speed, rate * delta)
		side = side.move_toward(Vector3.ZERO, deceleration * delta)
		flat = d * along + side
		var target_yaw := atan2(-d.x, -d.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))

	velocity.x = flat.x
	velocity.z = flat.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	return (flat - old_flat).dot(forward()) / delta


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
	_model.play_kick()
	if _ball_in_reach():
		_kick_ball(power)


func _ball_in_reach() -> bool:
	if ball == null:
		return false
	var to_ball := ball.global_position - global_position
	if to_ball.y > 1.0:
		return false
	to_ball.y = 0.0
	var dist := to_ball.length()
	if dist > kick_reach:
		return false
	# Мяч почти под ногами — бить можно в любую сторону, куда смотрим.
	if dist < 0.2:
		return true
	return rad_to_deg(forward().angle_to(to_ball)) <= kick_angle


func _kick_ball(power: float) -> void:
	var fwd := forward()
	var speed := lerpf(min_kick_speed, max_kick_speed, power)
	speed += maxf(Vector3(velocity.x, 0.0, velocity.z).dot(fwd), 0.0) * run_kick_bonus
	var lift := deg_to_rad(max_lift_angle) * clampf((power - lift_start) / (1.0 - lift_start), 0.0, 1.0)
	ball.kick(fwd * cos(lift) * speed + Vector3.UP * sin(lift) * speed)
	_cooldown = kick_cooldown
	_kick_sound.volume_db = linear_to_db(lerpf(0.45, 1.0, power))
	_kick_sound.pitch_scale = lerpf(1.1, 0.9, power)
	_kick_sound.play()


## Мягкое касание: если игрок налетает на мяч, мяч откатывается вперёд.
## Мяч, летящий в игрока, гасится (приём), а не проходит насквозь.
func _update_ball_touch() -> void:
	if ball == null or _cooldown > 0.0:
		return
	var to_ball := ball.global_position - global_position
	if to_ball.y > touch_height:
		return
	to_ball.y = 0.0
	var dist := to_ball.length()
	if dist > touch_radius or dist < 0.0001:
		return
	var n := to_ball / dist
	var my_v := Vector3(velocity.x, 0.0, velocity.z)
	var ball_v := Vector3(ball.linear_velocity.x, 0.0, ball.linear_velocity.z)
	var along := ball_v.dot(n)
	var target_along := maxf(my_v.dot(n), 0.0) * dribble_push + dribble_min_push
	if along >= target_along:
		return
	var out_dir := n
	var my_speed := my_v.length()
	if my_speed > 0.5 and (my_v / my_speed).dot(n) > 0.3:
		out_dir = n.lerp(my_v / my_speed, dribble_steer).normalized()
	var side := ball_v - n * along
	ball.touch(out_dir * target_along + side * 0.3)


func _reset_ball() -> void:
	if ball == null:
		return
	var target := global_position + forward() * 0.9
	target.y = ball.radius + 0.02
	# Не ставим мяч за забор или в стойку ворот.
	var from := global_position + Vector3.UP * target.y
	var query := PhysicsRayQueryParameters3D.create(from, target + forward() * ball.radius, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		target = hit.position - forward() * (ball.radius + 0.05)
		target.y = ball.radius + 0.02
	ball.reset_to(target)
