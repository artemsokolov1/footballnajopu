class_name Ball
extends RigidBody3D
## Футбольный мяч: свободная физика + сопротивление качению и воздуху.
## Удар и касания игрока задают скорость через kick()/touch(): других источников
## импульса от игрока нет (игрок и мяч не сталкиваются физически).

@export var radius := 0.11
## Постоянное замедление при качении по асфальту, м/с².
@export var rolling_resistance := 0.9
## Добавочное замедление, пропорциональное скорости при качении, 1/с.
@export var rolling_damping := 0.4
## Сопротивление воздуха (замедление = k * v²).
@export var air_drag := 0.008
## Минимальная скорость удара о поверхность для звука, м/с.
@export var impact_sound_speed := 1.2
## Куда вернуть мяч, если он вылетел за пределы двора.
@export var fallback_position := Vector3(0, 0.2, 0)

## Увеличивается при каждой телепортации — чтобы ворота не приняли её за пролёт.
var teleport_id := 0
## Кто последним держал мяч у ног (чтобы игроки не отбирали мяч друг у друга).
var controller: Footballer

var _pending_reset := false
var _reset_position := Vector3.ZERO
var _last_velocity := Vector3.ZERO
var _sound_cooldown := 0.0

@onready var _bounce_sound: AudioStreamPlayer3D = $BounceSound
@onready var _post_sound: AudioStreamPlayer3D = $PostSound


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_sound_cooldown = maxf(_sound_cooldown - delta, 0.0)
	if global_position.y < -3.0 or absf(global_position.x) > 60.0 or absf(global_position.z) > 60.0:
		reset_to(fallback_position)


## Удар: полностью задаёт новую скорость мяча.
func kick(velocity: Vector3) -> void:
	sleeping = false
	linear_velocity = velocity
	# Низкий мяч сразу катится без проскальзывания, иначе трение съедает скорость паса.
	# Верховой — без закрутки, иначе трение о борт подбрасывает его вверх.
	if absf(velocity.y) < 0.5:
		angular_velocity = Vector3.UP.cross(Vector3(velocity.x, 0.0, velocity.z)) / radius
	else:
		angular_velocity = Vector3.ZERO


## Касание при ведении: задаёт горизонтальную скорость, вертикальную не трогает.
func touch(horizontal_velocity: Vector3) -> void:
	sleeping = false
	linear_velocity = Vector3(horizontal_velocity.x, linear_velocity.y, horizontal_velocity.z)


## С какой скоростью катнуть мяч, чтобы через distance метров он катился со скоростью arrive_speed.
func speed_to_roll(distance: float, arrive_speed: float) -> float:
	var lo := arrive_speed
	var hi := 40.0
	for i in 24:
		var mid := (lo + hi) * 0.5
		if _roll_distance(mid, arrive_speed) < distance:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


## Путь катящегося мяча при замедлении от v0 до v1 (та же модель, что в _integrate_forces).
func _roll_distance(v0: float, v1: float) -> float:
	var dt := 1.0 / 60.0
	var v := v0
	var dist := 0.0
	while v > v1 and dist < 200.0:
		v -= (rolling_resistance + rolling_damping * v + air_drag * v * v) * dt
		dist += maxf(v, v1) * dt
	return dist


func reset_to(pos: Vector3) -> void:
	_pending_reset = true
	_reset_position = pos
	sleeping = false


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _pending_reset:
		_pending_reset = false
		state.transform = Transform3D(Basis.IDENTITY, _reset_position)
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_last_velocity = Vector3.ZERO
		controller = null
		teleport_id += 1
		reset_physics_interpolation.call_deferred()
		return

	var dt := state.step
	var v := state.linear_velocity
	# Катится — только если касается пола и не подпрыгивает (иначе в первый кадр
	# после верхового удара мяч получил бы закрутку качения).
	var grounded := false
	if absf(v.y) < 0.5:
		for i in state.get_contact_count():
			if state.get_contact_local_normal(i).y > 0.7:
				grounded = true
				break

	v -= v * v.length() * air_drag * dt

	if grounded:
		var flat := Vector3(v.x, 0.0, v.z)
		var speed := flat.length()
		if speed > 0.0001:
			var new_speed := maxf(speed - (rolling_resistance + rolling_damping * speed) * dt, 0.0)
			flat *= new_speed / speed
		v.x = flat.x
		v.z = flat.z
		# Вращение соответствует качению без проскальзывания.
		state.angular_velocity = Vector3.UP.cross(flat) / radius

	state.linear_velocity = v
	_last_velocity = v


func _on_body_entered(body: Node) -> void:
	if _sound_cooldown > 0.0:
		return
	var metal := body.is_in_group("metal")
	# Для пола важна вертикальная скорость, для стенок и штанг — полная.
	var impact := absf(_last_velocity.y) if body.is_in_group("ground") else _last_velocity.length()
	if impact < impact_sound_speed:
		return
	var player := _post_sound if metal else _bounce_sound
	player.volume_db = linear_to_db(clampf(impact / 12.0, 0.15, 1.0))
	player.pitch_scale = randf_range(0.93, 1.07)
	player.play()
	_sound_cooldown = 0.06
