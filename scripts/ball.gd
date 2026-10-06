class_name Ball
extends RigidBody3D
## Футбольный мяч: свободная физика + сопротивление качению и воздуху.
## Удар и касания игрока задают скорость через kick()/touch(): других источников
## импульса от игрока нет (игрок и мяч не сталкиваются физически).

@export var radius := 0.11
## Постоянное замедление при качении по асфальту, м/с².
@export var rolling_resistance := 0.9
## Добавочное замедление, пропорциональное скорости при качении, 1/с.
@export var rolling_damping := 0.3
## Сопротивление воздуха (замедление = k * v²).
@export var air_drag := 0.008
## Минимальная скорость удара о поверхность для звука, м/с.
@export var impact_sound_speed := 1.2
## Куда вернуть мяч, если он вылетел за пределы двора.
@export var fallback_position := Vector3(0, 0.2, 0)

## Увеличивается при каждой телепортации — чтобы ворота не приняли её за пролёт.
var teleport_id := 0

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
	# Без закрутки: иначе трение о борт подбрасывает мяч вверх.
	angular_velocity = Vector3.ZERO


## Касание при ведении: задаёт горизонтальную скорость, вертикальную не трогает.
func touch(horizontal_velocity: Vector3) -> void:
	sleeping = false
	linear_velocity = Vector3(horizontal_velocity.x, linear_velocity.y, horizontal_velocity.z)


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
		teleport_id += 1
		reset_physics_interpolation.call_deferred()
		return

	var dt := state.step
	var v := state.linear_velocity
	var grounded := false
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
		state.angular_velocity = state.angular_velocity.lerp(Vector3.UP.cross(flat) / radius, 0.3)

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
