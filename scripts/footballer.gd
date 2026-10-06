class_name Footballer
extends CharacterBody3D
## Общая часть игрока и напарника: бег, поворот, контроль мяча у ног, удар и пас.
## С мячом физически не сталкивается — на мяч действуют только ball.touch() и
## ball.kick(), поэтому двойного импульса не бывает.

@export var ball: Ball

@export_group("Movement")
## Скорость обычного бега, м/с.
@export var run_speed := 5.5
## Скорость с ускорением, м/с.
@export var sprint_speed := 8.0
## Разгон, м/с².
@export var acceleration := 26.0
## Торможение и гашение бокового скольжения, м/с².
@export var deceleration := 45.0
## Скорость поворота корпуса к направлению движения.
@export var turn_speed := 14.0
@export var gravity := 20.0

@export_group("Ball control")
## Мяч в этом радиусе (по горизонтали, от центра игрока) и перед игроком — «в ногах», м.
@export var control_radius := 0.95
## Половина угла сектора перед игроком, в котором мяч подбирается, градусы.
@export var control_angle := 100.0
## На каком расстоянии впереди держится мяч при обычном беге и на месте, м.
@export var control_distance := 0.5
## На каком расстоянии впереди держится мяч при спринте, м.
@export var control_distance_sprint := 0.85
## Насколько сильно мяч тянется к точке у ног (1/с).
@export var control_strength := 9.0
## Насколько быстро скорость мяча подстраивается под нужную (1/с). Больше — «липче».
@export var control_grip := 14.0
## Мяч, летящий относительно игрока быстрее этого, сначала гасится, а не подбирается, м/с.
@export var control_max_speed := 9.0
## Выше этой высоты центра мяча контроля нет, м.
@export var control_height := 0.5
## Горизонтальное расстояние центр–центр, на котором тело блокирует мяч, м.
@export var touch_radius := 0.5
## Выше этой высоты центра мяча тело мяч не блокирует, м.
@export var touch_height := 1.7
## Минимальная скорость, с которой мяч отходит от тела после касания, м/с.
@export var touch_min_push := 0.6

@export_group("Kick")
## Дальность удара и паса: максимальное горизонтальное расстояние до центра мяча, м.
@export var kick_reach := 1.1
## Половина угла сектора перед игроком, в котором мяч можно ударить, градусы.
@export var kick_angle := 65.0
## Скорость мяча при коротком нажатии удара, м/с.
@export var min_kick_speed := 7.0
## Скорость мяча при полном наборе, м/с.
@export var max_kick_speed := 24.0
## Угол подъёма мяча при полной силе, градусы.
@export var max_lift_angle := 12.0
## С какой силы (0..1) мяч начинает подниматься.
@export_range(0.0, 1.0) var lift_start := 0.5
## Доля скорости бега, добавляемая к удару.
@export var run_kick_bonus := 0.3
## Пауза после удара или паса, когда контроль и касания отключены, с.
@export var kick_cooldown := 0.3

@export_group("Pass")
## С какой скоростью пас должен приходить к адресату, м/с.
@export var pass_arrive_speed := 3.5
## Пределы скорости паса, м/с.
@export var min_pass_speed := 5.0
@export var max_pass_speed := 17.0
## Дальность паса «в никуда», когда адресата нет в секторе, м.
@export var free_pass_distance := 10.0

var _cooldown := 0.0
var _has_ball_frame := -100

@onready var _model := $Model
@onready var _kick_sound: AudioStreamPlayer3D = $KickSound


func forward() -> Vector3:
	return -global_basis.z


func flat_velocity() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


## Мяч под контролем этого игрока (в последние несколько кадров).
func has_ball() -> bool:
	return Engine.get_physics_frames() - _has_ball_frame <= 6


func ball_in_reach() -> bool:
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


## Шаг движения. dir — желаемое направление (длина 0..1 задаёт долю скорости),
## face_dir — куда смотреть, если стоим. Возвращает продольное ускорение для анимации.
func _move(delta: float, dir: Vector3, sprint: bool, face_dir := Vector3.ZERO) -> float:
	var flat := flat_velocity()
	var old_flat := flat
	var look := face_dir
	if dir.length_squared() < 0.0001:
		flat = flat.move_toward(Vector3.ZERO, deceleration * delta)
	else:
		var max_speed := sprint_speed if sprint else run_speed
		var d := dir.normalized()
		var target_speed := max_speed * minf(dir.length(), 1.0)
		var along := flat.dot(d)
		var side := flat - d * along
		# Разворот гасим быстро, разгон и сброс скорости после спринта — плавно.
		var rate := deceleration if along < 0.0 else acceleration
		along = move_toward(along, target_speed, rate * delta)
		side = side.move_toward(Vector3.ZERO, deceleration * delta)
		flat = d * along + side
		look = d
	look.y = 0.0
	if look.length_squared() > 0.0001:
		var target_yaw := atan2(-look.x, -look.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))

	velocity.x = flat.x
	velocity.z = flat.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	return (flat - old_flat).dot(forward()) / delta


## Контроль мяча у ног, а если мяч не в секторе контроля — блокировка телом.
func _update_ball_contact(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if ball == null or _cooldown > 0.0:
		return
	if ball.controller != null and ball.controller != self and ball.controller.has_ball():
		return
	if not _try_control(delta):
		_body_touch()


func _try_control(delta: float) -> bool:
	var to_ball := ball.global_position - global_position
	if to_ball.y > control_height:
		return false
	to_ball.y = 0.0
	var dist := to_ball.length()
	# Уже ведём мяч — держим его и на разворотах, подбираем — только спереди.
	var keeping := has_ball()
	if dist > control_radius * (1.3 if keeping else 1.0):
		return false
	var angle := rad_to_deg(forward().angle_to(to_ball)) if dist > 0.05 else 0.0
	if not keeping and angle > control_angle:
		return false
	var my_v := flat_velocity()
	var ball_v := Vector3(ball.linear_velocity.x, 0.0, ball.linear_velocity.z)
	if (ball_v - my_v).length() > control_max_speed:
		return false

	# Мяч держится чуть впереди; на спринте — дальше, как при ведении «на ход».
	var sprint_t := clampf((my_v.length() - run_speed) / maxf(sprint_speed - run_speed, 0.01), 0.0, 1.0)
	var hold := lerpf(control_distance, control_distance_sprint, sprint_t)
	var spot_dir := forward()
	if angle > 70.0:
		# Мяч сбоку или сзади — проводим его вокруг ног, а не сквозь игрока.
		var side := (to_ball - forward() * to_ball.dot(forward())).normalized()
		spot_dir = (side + forward() * 0.6).normalized()
	var spot := global_position + spot_dir * hold
	var to_spot := spot - ball.global_position
	to_spot.y = 0.0
	var desired := my_v + to_spot * control_strength
	desired = desired.limit_length(sprint_speed + 4.0)
	ball.touch(ball_v.lerp(desired, 1.0 - exp(-control_grip * delta)))
	ball.controller = self
	_has_ball_frame = Engine.get_physics_frames()
	return true


## Тело не пропускает мяч: мяч, налетевший на игрока, мягко отходит от него.
func _body_touch() -> void:
	var to_ball := ball.global_position - global_position
	if to_ball.y > touch_height:
		return
	to_ball.y = 0.0
	var dist := to_ball.length()
	if dist > touch_radius or dist < 0.0001:
		return
	var n := to_ball / dist
	var my_v := flat_velocity()
	var ball_v := Vector3(ball.linear_velocity.x, 0.0, ball.linear_velocity.z)
	var along := ball_v.dot(n)
	var target_along := maxf(my_v.dot(n), 0.0) + touch_min_push
	if along >= target_along:
		return
	var side := ball_v - n * along
	ball.touch(n * target_along + side * 0.3)


## Удар по направлению корпуса. power 0..1.
func _kick(power: float) -> void:
	_model.play_kick()
	if not ball_in_reach():
		return
	var fwd := forward()
	var speed := lerpf(min_kick_speed, max_kick_speed, power)
	speed += maxf(flat_velocity().dot(fwd), 0.0) * run_kick_bonus
	var lift := deg_to_rad(max_lift_angle) * clampf((power - lift_start) / (1.0 - lift_start), 0.0, 1.0)
	_strike(fwd * cos(lift) * speed + Vector3.UP * sin(lift) * speed, lerpf(0.45, 1.0, power), lerpf(1.1, 0.9, power))


## Пас по земле в точку target: сила подбирается так, чтобы мяч пришёл со скоростью
## pass_arrive_speed. Возвращает true, если мяч был в досягаемости.
func _pass_to(target: Vector3) -> bool:
	_model.play_kick()
	if not ball_in_reach():
		return false
	var dir := target - ball.global_position
	dir.y = 0.0
	var dist := dir.length()
	if dist < 0.1:
		dir = forward()
	var speed := clampf(ball.speed_to_roll(dist, pass_arrive_speed), min_pass_speed, max_pass_speed)
	_strike(dir.normalized() * speed, 0.4, 1.2)
	return true


func _strike(velocity_out: Vector3, volume: float, pitch: float) -> void:
	ball.kick(velocity_out)
	ball.controller = null
	_has_ball_frame = -100
	_cooldown = kick_cooldown
	_kick_sound.volume_db = linear_to_db(volume)
	_kick_sound.pitch_scale = pitch
	_kick_sound.play()


func _animate(delta: float, accel: float, charge := -1.0) -> void:
	_model.update_pose(delta, flat_velocity().length(), run_speed, charge, accel)
