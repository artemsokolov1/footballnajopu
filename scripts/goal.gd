class_name Goal
extends Node3D
## Металлические ворота без сетки. Строят свою геометрию и коллизии
## и засчитывают гол, когда мяч целиком пересекает линию между штангами.
## Ворота смотрят в сторону +Z: поле перед ними, внутренняя часть — за линией (−Z).

signal scored

@export var ball: Ball
## Расстояние между осями штанг, м.
@export var width := 4.0
## Высота перекладины (до оси), м.
@export var height := 2.0
## Насколько назад уходят задние стойки, м.
@export var depth := 1.2
@export var bar_radius := 0.05
@export var color := Color(0.92, 0.92, 0.9)

var _armed := true
var _prev_local := Vector3.ZERO
var _seen_teleport := -1

@onready var _whistle: AudioStreamPlayer = $Whistle


func _ready() -> void:
	_build()


func _physics_process(_delta: float) -> void:
	if ball == null:
		return
	var p := to_local(ball.global_position)
	var r := ball.radius
	if ball.teleport_id != _seen_teleport:
		_seen_teleport = ball.teleport_id
		_prev_local = p
		_armed = true
		return

	# Мяч целиком за линией, если его центр дальше линии на радиус.
	if _armed and _prev_local.z >= -r and p.z < -r:
		var t := (_prev_local.z + r) / (_prev_local.z - p.z)
		var hit := _prev_local.lerp(p, t)
		var inner_half := width * 0.5 - bar_radius
		if absf(hit.x) < inner_half and hit.y < height - bar_radius:
			_armed = false
			_whistle.play()
			scored.emit()
	# Снова засчитываем только после того, как мяч вернулся на поле.
	if not _armed and p.z > 1.0:
		_armed = true
	_prev_local = p


func _build() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.5
	mat.roughness = 0.45

	var body := StaticBody3D.new()
	body.name = "Frame"
	body.add_to_group("metal")
	add_child(body)

	var hw := width * 0.5
	var bars := [
		[Vector3(-hw, 0, 0), Vector3(-hw, height, 0)],
		[Vector3(hw, 0, 0), Vector3(hw, height, 0)],
		[Vector3(-hw, height, 0), Vector3(hw, height, 0)],
		[Vector3(-hw, height, 0), Vector3(-hw, 0, -depth)],
		[Vector3(hw, height, 0), Vector3(hw, 0, -depth)],
		[Vector3(-hw, 0.03, -depth), Vector3(hw, 0.03, -depth)],
	]
	for i in bars.size():
		# Нижняя задняя перекладина тоньше, чтобы мяч не подпрыгивал на ней.
		var r := bar_radius * 0.6 if i == bars.size() - 1 else bar_radius
		_add_bar(body, bars[i][0], bars[i][1], r, mat)


func _add_bar(body: StaticBody3D, a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var length := a.distance_to(b)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var xform := Transform3D(Basis(x, y, z), (a + b) * 0.5)

	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	# Удлиняем на радиус с каждой стороны, чтобы углы рамы смыкались.
	mesh.height = length + r * 2.0
	mesh.radial_segments = 12
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xform
	add_child(mi)

	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = length + r * 2.0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xform
	body.add_child(cs)
