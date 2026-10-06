extends Node3D
## Временная модель человека из примитивов с процедурной анимацией
## (бег, замах при наборе силы, удар). Смотрит вдоль −Z, начало координат — у ступней.
## Поворот сустава по +X выносит конечность вперёд (к −Z).

@export var shirt_color := Color(0.82, 0.22, 0.16)
@export var shorts_color := Color(0.1, 0.13, 0.28)
@export var skin_color := Color(0.92, 0.73, 0.58)
@export var hair_color := Color(0.2, 0.13, 0.08)
@export var sock_color := Color(0.92, 0.92, 0.9)
@export var shoe_color := Color(0.08, 0.08, 0.09)
## Длительность анимации удара, с.
@export var kick_duration := 0.32

var _pelvis: Node3D
var _torso: Node3D
var _thighs: Array[Node3D] = []
var _shins: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _forearms: Array[Node3D] = []

var _phase := 0.0
var _run_weight := 0.0
var _wind := 0.0
var _swing_t := -1.0
var _swing_thigh_from := 0.0
var _swing_shin_from := 0.0
var _lean := 0.0
var _materials := {}


func _ready() -> void:
	_build()


## Запустить анимацию удара (замах уже набран через update_pose).
func play_kick() -> void:
	_swing_t = 0.0
	_swing_thigh_from = _thighs[1].rotation.x
	_swing_shin_from = _shins[1].rotation.x


## speed — горизонтальная скорость, run_speed — скорость обычного бега,
## charge — набранная сила удара 0..1 (−1, если удар не заряжается),
## accel — продольное ускорение для наклона корпуса.
func update_pose(delta: float, speed: float, run_speed: float, charge: float, accel: float) -> void:
	var ratio := clampf(speed / run_speed, 0.0, 1.5)
	_run_weight = lerpf(_run_weight, minf(ratio, 1.0), 1.0 - exp(-12.0 * delta))
	# Частота шагов: длина шага растёт со скоростью.
	_phase = fmod(_phase + delta * TAU * speed / (2.0 * (0.8 + 0.15 * speed)), TAU)

	var amp_thigh := 0.25 + 0.5 * minf(ratio, 1.2)
	var amp_knee := 0.4 + 0.9 * minf(ratio, 1.2)
	var amp_arm := 0.2 + 0.45 * minf(ratio, 1.2)
	var w := _run_weight

	for i in 2:
		var ph := _phase + PI * i
		var s := sin(ph)
		var thigh := s * amp_thigh * w
		var shin := -(maxf(cos(ph), 0.0) * amp_knee + 0.15) * w - 0.05 * (1.0 - w)
		_thighs[i].rotation.x = thigh
		_shins[i].rotation.x = shin
		_arms[i].rotation.x = -s * amp_arm * w
		_arms[i].rotation.z = (0.12 + 0.06 * w) * (-1.0 if i == 0 else 1.0)
		_forearms[i].rotation.x = 0.25 + 1.0 * w

	# Подпрыгивание при беге.
	_pelvis.position.y = 0.93 + absf(cos(_phase)) * 0.05 * w - 0.03 * w

	# Замах при наборе силы.
	var wind_target := 0.0 if charge < 0.0 else 0.35 + 0.65 * charge
	_wind = lerpf(_wind, wind_target, 1.0 - exp(-14.0 * delta))
	var wind_thigh := -0.2 - 0.6 * _wind
	var wind_shin := -0.5 - 0.9 * _wind
	_thighs[1].rotation.x = lerpf(_thighs[1].rotation.x, wind_thigh, _wind)
	_shins[1].rotation.x = lerpf(_shins[1].rotation.x, wind_shin, _wind)
	_arms[0].rotation.x = lerpf(_arms[0].rotation.x, 0.6, _wind)
	_arms[0].rotation.z = lerpf(_arms[0].rotation.z, -0.7, _wind)
	_arms[1].rotation.x = lerpf(_arms[1].rotation.x, -0.5, _wind)
	_arms[1].rotation.z = lerpf(_arms[1].rotation.z, 0.4, _wind)
	var lean_target := -0.1 * minf(ratio, 1.3) - clampf(accel * 0.012, -0.12, 0.12) + 0.12 * _wind

	# Удар: быстрый мах вперёд и возврат.
	if _swing_t >= 0.0:
		_swing_t += delta / kick_duration
		var thigh_now := _thighs[1].rotation.x
		var shin_now := _shins[1].rotation.x
		var k: float
		var thigh: float
		var shin: float
		if _swing_t < 0.35:
			k = ease(_swing_t / 0.35, 0.5)
			thigh = lerpf(_swing_thigh_from, 1.2, k)
			shin = lerpf(_swing_shin_from, -0.05, k)
		else:
			k = smoothstep(0.35, 1.0, _swing_t)
			thigh = lerpf(1.2, thigh_now, k)
			shin = lerpf(-0.05, shin_now, k)
		_thighs[1].rotation.x = thigh
		_shins[1].rotation.x = shin
		_arms[0].rotation.x = 0.7
		_arms[0].rotation.z = -0.8
		_arms[1].rotation.x = -0.7
		lean_target += 0.15 * (1.0 - absf(_swing_t - 0.35) * 1.5)
		if _swing_t >= 1.0:
			_swing_t = -1.0
			_wind = 0.0

	_lean = lerpf(_lean, lean_target, 1.0 - exp(-10.0 * delta))
	_torso.rotation.x = _lean


func _build() -> void:
	_pelvis = _pivot(self, Vector3(0, 0.93, 0))
	_box(_pelvis, Vector3(0.34, 0.2, 0.2), Vector3(0, 0, 0), shorts_color)

	_torso = _pivot(_pelvis, Vector3(0, 0.05, 0))
	var chest := _capsule(_torso, 0.6, 0.17, Vector3(0, 0.28, 0), shirt_color)
	chest.scale = Vector3(1.0, 1.0, 0.72)
	_capsule(_torso, 0.12, 0.05, Vector3(0, 0.6, 0), skin_color)
	_sphere(_torso, 0.12, Vector3(0, 0.74, 0), skin_color)
	var hair := _sphere(_torso, 0.125, Vector3(0, 0.77, 0.015), hair_color)
	hair.scale = Vector3(1.0, 0.8, 1.0)
	# Нос, чтобы было видно, куда смотрит голова.
	_box(_torso, Vector3(0.03, 0.04, 0.05), Vector3(0, 0.73, -0.12), skin_color)

	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var shoulder := _pivot(_torso, Vector3(0.23 * side, 0.48, 0))
		_capsule(shoulder, 0.16, 0.065, Vector3(0, -0.06, 0), shirt_color)
		_capsule(shoulder, 0.3, 0.05, Vector3(0, -0.15, 0), skin_color)
		var elbow := _pivot(shoulder, Vector3(0, -0.3, 0))
		_capsule(elbow, 0.3, 0.045, Vector3(0, -0.14, 0), skin_color)
		_arms.append(shoulder)
		_forearms.append(elbow)

		var hip := _pivot(_pelvis, Vector3(0.1 * side, -0.05, 0))
		_capsule(hip, 0.2, 0.085, Vector3(0, -0.07, 0), shorts_color)
		_capsule(hip, 0.46, 0.07, Vector3(0, -0.22, 0), skin_color)
		var knee := _pivot(hip, Vector3(0, -0.44, 0))
		_capsule(knee, 0.3, 0.058, Vector3(0, -0.24, 0), sock_color)
		_capsule(knee, 0.2, 0.06, Vector3(0, -0.08, 0), skin_color)
		_box(knee, Vector3(0.1, 0.08, 0.25), Vector3(0, -0.4, -0.05), shoe_color)
		_thighs.append(hip)
		_shins.append(knee)


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.8
		_materials[color] = m
	return _materials[color]


func _add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _material(color)
	parent.add_child(mi)
	return mi


func _capsule(parent: Node3D, length: float, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(length, radius * 2.0)
	m.radial_segments = 12
	m.rings = 4
	return _add_mesh(parent, m, pos, color)


func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 16
	m.rings = 8
	return _add_mesh(parent, m, pos, color)


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add_mesh(parent, m, pos, color)
