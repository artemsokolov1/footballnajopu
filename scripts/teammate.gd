class_name Teammate
extends Footballer
## Напарник с простым поведением: открывается под пас, принимает мяч
## и отдаёт его обратно игроку.

## Игрок, с которым напарник разыгрывает мяч.
@export var partner: Footballer

@export_group("AI")
## Насколько напарник открывается вбок и вперёд от игрока, м.
@export var support_offset := Vector2(5.0, 5.0)
## Пауза между приёмом мяча и пасом обратно, с.
@export var pass_delay := 0.45
## Поле, за которое напарник не выходит (половина размеров, x — ширина, y — длина), м.
@export var area_half_size := Vector2(7.5, 13.0)

var _hold_time := 0.0
var _side := 1.0


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	var sprint := false
	var face := Vector3.ZERO
	if ball:
		face = ball.global_position - global_position

	if has_ball() and partner:
		_hold_time += delta
		var target := _pass_target()
		face = target - global_position
		face.y = 0.0
		var aimed := rad_to_deg(forward().angle_to(face)) < 15.0
		if (_hold_time > pass_delay and aimed) or _hold_time > 2.5:
			_pass_to(target)
	else:
		_hold_time = 0.0
		var goal := _choose_spot()
		var to_goal := goal - global_position
		to_goal.y = 0.0
		var dist := to_goal.length()
		if dist > 0.3:
			# Плавно замедляемся у точки, далеко — бежим с ускорением.
			dir = to_goal / dist * clampf(dist / 2.0, 0.0, 1.0)
			sprint = dist > 6.0

	var accel := _move(delta, dir, sprint, face)
	_update_ball_contact(delta)
	_animate(delta, accel)


## Куда бежать: к мячу, на перехват паса или открываться.
func _choose_spot() -> Vector3:
	if ball == null or partner == null:
		return global_position
	var ball_pos := Vector3(ball.global_position.x, 0.0, ball.global_position.z)
	var ball_v := Vector3(ball.linear_velocity.x, 0.0, ball.linear_velocity.z)
	var me := Vector3(global_position.x, 0.0, global_position.z)
	if partner.has_ball():
		return _support_spot()
	# Мяч катится ко мне — выходим на линию его движения.
	var speed := ball_v.length()
	if speed > 1.5 and ball_v.dot(me - ball_pos) > 0.0:
		var t := clampf((me - ball_pos).dot(ball_v) / (speed * speed), 0.0, 3.0)
		var meet := ball_pos + ball_v * t
		if meet.distance_to(me) < 4.0:
			return _clamp_to_area(meet)
	# Бесхозный мяч ближе ко мне, чем к игроку, — забираем.
	var partner_pos := Vector3(partner.global_position.x, 0.0, partner.global_position.z)
	if ball_pos.distance_to(me) < ball_pos.distance_to(partner_pos) - 0.5:
		return ball_pos + ball_v * 0.3
	return _support_spot()


## Точка «под пас»: сбоку и впереди (ближе к воротам) от игрока.
func _support_spot() -> Vector3:
	var p := partner.global_position
	if absf(p.x) > 1.5:
		_side = -signf(p.x)
	var spot := Vector3(p.x + _side * support_offset.x, 0.0, p.z - support_offset.y)
	return _clamp_to_area(spot)


func _clamp_to_area(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -area_half_size.x, area_half_size.x), 0.0,
			clampf(p.z, -area_half_size.y, area_half_size.y))


## Пас на ход: туда, где игрок будет к приходу мяча.
func _pass_target() -> Vector3:
	var to_partner := partner.global_position - global_position
	to_partner.y = 0.0
	var travel := to_partner.length() / 9.0
	return partner.global_position + partner.flat_velocity() * minf(travel, 1.0)
