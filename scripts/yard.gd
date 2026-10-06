extends Node3D
## Двор: ровный асфальт с разметкой, «коробка» с бортами и сеткой,
## скамейка, деревья и панельные дома вокруг. Всё собирается из примитивов.

## Половина размеров разметки поля (x — ширина, y — длина), м.
@export var field_half_size := Vector2(8.0, 14.0)
## Половина размеров коробки по забору, м.
@export var fence_half_size := Vector2(10.5, 17.0)
@export var board_height := 1.0
@export var fence_height := 3.5
@export var board_color := Color(0.22, 0.42, 0.33)

const ASPHALT_SHADER := preload("res://shaders/asphalt.gdshader")
const GROUND_SHADER := preload("res://shaders/ground.gdshader")
const CHAIN_SHADER := preload("res://shaders/chain_link.gdshader")
const BUILDING_SHADER := preload("res://shaders/panel_building.gdshader")

var _materials := {}


func _ready() -> void:
	_build_ground()
	_build_fence()
	_build_bench(Vector3(-fence_half_size.x + 0.7, 0, 3.0), -PI * 0.5)
	_build_buildings()
	_build_trees()


func _build_ground() -> void:
	# Пол — один плоский бокс: трещины только в шейдере и не влияют на физику.
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.add_to_group("ground")
	add_child(floor_body)
	var shape := BoxShape3D.new()
	shape.size = Vector3(200, 1, 200)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, -0.5, 0)
	floor_body.add_child(cs)

	var asphalt := ShaderMaterial.new()
	asphalt.shader = ASPHALT_SHADER
	asphalt.set_shader_parameter("field_half_size", field_half_size)
	var plane := PlaneMesh.new()
	plane.size = fence_half_size * 2.0 + Vector2(1.0, 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = asphalt
	add_child(mi)

	var grass := ShaderMaterial.new()
	grass.shader = GROUND_SHADER
	var outer := PlaneMesh.new()
	outer.size = Vector2(200, 200)
	var gi := MeshInstance3D.new()
	gi.mesh = outer
	gi.material_override = grass
	gi.position.y = -0.01
	add_child(gi)


func _build_fence() -> void:
	var body := StaticBody3D.new()
	body.name = "Fence"
	add_child(body)
	var board_mat := _mat(board_color, 0.85)
	var post_mat := _mat(Color(0.3, 0.32, 0.33), 0.5, 0.6)
	var chain := ShaderMaterial.new()
	chain.shader = CHAIN_SHADER

	var hx := fence_half_size.x
	var hz := fence_half_size.y
	# Стороны: центр, длина, вдоль X или вдоль Z.
	var sides := [
		[Vector3(0, 0, -hz), hx * 2.0, true],
		[Vector3(0, 0, hz), hx * 2.0, true],
		[Vector3(-hx, 0, 0), hz * 2.0, false],
		[Vector3(hx, 0, 0), hz * 2.0, false],
	]
	for s in sides:
		var center: Vector3 = s[0]
		var length: float = s[1]
		var along_x: bool = s[2]
		var size := Vector3(length, board_height, 0.06) if along_x else Vector3(0.06, board_height, length)
		_box_mesh(size, center + Vector3(0, board_height * 0.5, 0), board_mat)
		# Невидимая высокая стенка, чтобы мяч не улетал со двора.
		var wall := BoxShape3D.new()
		wall.size = Vector3(size.x + 0.4, 6.0, 0.4) if along_x else Vector3(0.4, 6.0, size.z + 0.4)
		var cs := CollisionShape3D.new()
		cs.shape = wall
		cs.position = center + Vector3(0, 3.0, 0) + (Vector3(0, 0, signf(center.z) * 0.2) if along_x else Vector3(signf(center.x) * 0.2, 0, 0))
		body.add_child(cs)

		var quad := QuadMesh.new()
		quad.size = Vector2(length, fence_height - board_height)
		var qi := MeshInstance3D.new()
		qi.mesh = quad
		qi.material_override = chain
		qi.position = center + Vector3(0, (fence_height + board_height) * 0.5, 0)
		if not along_x:
			qi.rotation.y = PI * 0.5
		qi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(qi)

		var rail := Vector3(length, 0.05, 0.05) if along_x else Vector3(0.05, 0.05, length)
		_box_mesh(rail, center + Vector3(0, fence_height, 0), post_mat)
		var posts := int(length / 3.0)
		for i in posts + 1:
			var t := -0.5 + float(i) / posts
			var p := center + (Vector3(t * length, 0, 0) if along_x else Vector3(0, 0, t * length))
			_cylinder_mesh(0.045, fence_height, p + Vector3(0, fence_height * 0.5, 0), post_mat)


func _build_bench(pos: Vector3, yaw: float) -> void:
	var root := StaticBody3D.new()
	root.name = "Bench"
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	var wood := _mat(Color(0.55, 0.36, 0.2), 0.8)
	var concrete := _mat(Color(0.6, 0.58, 0.55), 0.95)
	for x in [-0.8, 0.8]:
		_box_mesh(Vector3(0.1, 0.45, 0.4), Vector3(x, 0.225, 0), concrete, root)
		_box_mesh(Vector3(0.08, 0.5, 0.08), Vector3(x, 0.7, 0.17), concrete, root)
	for i in 3:
		_box_mesh(Vector3(2.0, 0.05, 0.11), Vector3(0, 0.47, -0.13 + i * 0.13), wood, root)
	for i in 2:
		_box_mesh(Vector3(2.0, 0.1, 0.04), Vector3(0, 0.65 + i * 0.16, 0.2), wood, root)
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 0.5, 0.45)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, 0.25, 0)
	root.add_child(cs)
	var back := BoxShape3D.new()
	back.size = Vector3(2.0, 0.45, 0.08)
	var cs2 := CollisionShape3D.new()
	cs2.shape = back
	cs2.position = Vector3(0, 0.72, 0.19)
	root.add_child(cs2)


func _build_buildings() -> void:
	# [центр, размер, зерно для окон]
	var houses := [
		[Vector3(-4, 0, -31), Vector3(64, 25.2, 12), 1.0],
		[Vector3(-27, 0, 2), Vector3(12, 14.0, 44), 2.0],
		[Vector3(26, 0, -4), Vector3(12, 25.2, 40), 3.0],
		[Vector3(6, 0, 34), Vector3(50, 14.0, 12), 4.0],
	]
	for h in houses:
		var size: Vector3 = h[1]
		var mat := ShaderMaterial.new()
		mat.shader = BUILDING_SHADER
		mat.set_shader_parameter("seed", h[2])
		# Высота кратна этажу + цоколь.
		size.y += 1.0
		_box_mesh(size, h[0] + Vector3(0, size.y * 0.5, 0), mat)


func _build_trees() -> void:
	var trunk_mat := _mat(Color(0.33, 0.25, 0.18), 0.9)
	var leaves := [
		_mat(Color(0.24, 0.36, 0.14), 0.85),
		_mat(Color(0.3, 0.4, 0.15), 0.85),
		_mat(Color(0.2, 0.32, 0.14), 0.85),
	]
	var spots := [
		Vector3(-14, 0, -11), Vector3(-15.5, 0, 4), Vector3(-13.5, 0, 14),
		Vector3(14.5, 0, -6), Vector3(13.5, 0, 9), Vector3(7, 0, -21),
		Vector3(-9, 0, -21.5), Vector3(17, 0, 20), Vector3(-17, 0, -20),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for p in spots:
		var height := rng.randf_range(4.0, 6.0)
		var tree := StaticBody3D.new()
		tree.position = p
		add_child(tree)
		_cylinder_mesh(0.18, height, Vector3(0, height * 0.5, 0), trunk_mat, tree)
		var shape := CylinderShape3D.new()
		shape.radius = 0.2
		shape.height = height
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position.y = height * 0.5
		tree.add_child(cs)
		for i in 4:
			var r := rng.randf_range(1.3, 2.0)
			var m := SphereMesh.new()
			m.radius = r
			m.height = r * 1.8
			m.radial_segments = 10
			m.rings = 6
			var mi := MeshInstance3D.new()
			mi.mesh = m
			mi.material_override = leaves[rng.randi() % leaves.size()]
			mi.position = Vector3(rng.randf_range(-1, 1), height + rng.randf_range(-0.6, 1.2), rng.randf_range(-1, 1))
			tree.add_child(mi)


func _mat(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var key := [color, roughness, metallic]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		m.metallic = metallic
		_materials[key] = m
	return _materials[key]


func _box_mesh(size: Vector3, pos: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _cylinder_mesh(radius: float, height: float, pos: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi
