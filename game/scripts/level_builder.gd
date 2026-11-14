class_name LevelBuilder
extends Node3D

# Builds a level from its description: grey-box floor, walls and pillars with collision, and the
# navigation mesh the AI walks on. It also answers the rules' questions about the place.

const GRID := preload("res://shaders/grid.gdshader")
# a unit's half-width, kept clear of walls by the navigation mesh
const AGENT_RADIUS := 0.5
# line of sight is judged at about chest height, so low kerbs and crates do not block it
const EYE := Vector3(0, 1.3, 0)
const KNEE := Vector3(0, 0.5, 0)
const WALLS := 1

var def: LevelDef

var _region: NavigationRegion3D
var _pillars: Array[StaticBody3D] = []
var _wall_mat: StandardMaterial3D
var _pillar_mat: StandardMaterial3D


func build(level: LevelDef) -> void:
	def = level
	_wall_mat = StandardMaterial3D.new()
	_wall_mat.albedo_color = Color(0.5, 0.52, 0.56)
	_pillar_mat = StandardMaterial3D.new()
	_pillar_mat.albedo_color = Color(0.44, 0.4, 0.36)
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = GRID

	for f in def.floors:
		var slab := BoxMesh.new()
		slab.size = Vector3(f.size.x, 0.5, f.size.y)
		var floor_part := MeshInstance3D.new()
		floor_part.mesh = slab
		floor_part.material_override = floor_mat
		floor_part.position = Vector3(f.get_center().x, -0.25, f.get_center().y)
		add_child(floor_part)

	for w in def.walls:
		var r: Rect2 = w.rect
		var box := BoxShape3D.new()
		box.size = Vector3(r.size.x, w.height, r.size.y)
		var block := BoxMesh.new()
		block.size = box.size
		_solid(box, block, _wall_mat, Vector3(r.get_center().x, w.height / 2.0, r.get_center().y))

	for p in def.pillars:
		var round := CylinderShape3D.new()
		round.radius = p.r
		round.height = p.height
		var column := CylinderMesh.new()
		column.top_radius = p.r
		column.bottom_radius = p.r
		column.height = p.height
		column.radial_segments = 20
		var body := _solid(round, column, _pillar_mat, p.pos + Vector3(0, p.height / 2.0, 0))
		body.set_meta("pillar", _pillars.size())
		_pillars.append(body)

	_region = NavigationRegion3D.new()
	add_child(_region)
	_bake()


func _solid(shape: Shape3D, mesh: Mesh, mat: Material, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = WALLS
	body.collision_mask = 0
	var hull := CollisionShape3D.new()
	hull.shape = shape
	body.add_child(hull)
	var look := MeshInstance3D.new()
	look.mesh = mesh
	look.material_override = mat
	body.add_child(look)
	body.position = at
	add_child(body)
	return body


# The navigation mesh is made from the description, not from the meshes: the floor rectangles
# are walkable, and each wall and standing pillar is cut out with a unit's half-width to spare.
func _bake() -> void:
	var nav := NavigationMesh.new()
	nav.agent_radius = AGENT_RADIUS
	nav.agent_height = 2.0
	nav.agent_max_climb = 0.25
	nav.cell_size = 0.25
	nav.cell_height = 0.25
	var src := NavigationMeshSourceGeometryData3D.new()
	for f in def.floors:
		var a := Vector3(f.position.x, 0, f.position.y)
		var b := Vector3(f.end.x, 0, f.position.y)
		var c := Vector3(f.end.x, 0, f.end.y)
		var d := Vector3(f.position.x, 0, f.end.y)
		src.add_faces(PackedVector3Array([a, b, c, a, c, d]), Transform3D.IDENTITY)
	for w in def.walls:
		var r: Rect2 = w.rect
		src.add_projected_obstruction(PackedVector3Array([
			Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0, r.position.y),
			Vector3(r.end.x, 0, r.end.y), Vector3(r.position.x, 0, r.end.y)]), 0.0, w.height, false)
	for i in def.pillars.size():
		if not is_standing(i):
			continue
		var p: Dictionary = def.pillars[i]
		var ring := PackedVector3Array()
		for k in 12:
			var turn := k / 12.0 * TAU
			ring.append(p.pos + Vector3(cos(turn), 0, sin(turn)) * p.r)
		src.add_projected_obstruction(ring, 0.0, p.height, false)
	NavigationServer3D.bake_from_source_geometry_data(nav, src)
	_region.navigation_mesh = nav
	NavigationServer3D.map_force_update(get_world_3d().navigation_map)


## How many walkable polygons the navigation mesh has; none means it failed to build.
func nav_polygons() -> int:
	return _region.navigation_mesh.get_polygon_count()


# ---------- what the rules ask about the place

## The way to walk from one spot to another, as corners to pass. Empty if there is none.
func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not _nav_ready():
		return PackedVector3Array()
	return NavigationServer3D.map_get_path(get_world_3d().navigation_map, from, to, true)


func can_stand(p: Vector3) -> bool:
	if not _nav_ready():
		return def.can_stand(p, AGENT_RADIUS)
	var on := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, p)
	return Combat.flat(on, p) < 0.3


# The engine takes a frame to take in a new navigation mesh; until then it cannot be asked.
func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0


func sees(a: Vector3, b: Vector3) -> bool:
	return _ray(a + EYE, b + EYE).is_empty()


func clear_walk(a: Vector3, b: Vector3) -> bool:
	return _ray(a + KNEE, b + KNEE).is_empty()


## Which pillar stands between two spots, or -1.
func pillar_between(a: Vector3, b: Vector3) -> int:
	var hit := _ray(a + EYE, b + EYE)
	if hit.is_empty() or not hit.collider.has_meta("pillar"):
		return -1
	return hit.collider.get_meta("pillar")


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, WALLS))


# ---------- pillars that fall

func is_standing(i: int) -> bool:
	return i >= _pillars.size() or _pillars[i].visible


func destroy_pillar(i: int) -> void:
	if i < 0 or i >= _pillars.size() or not _pillars[i].visible:
		return
	_stand(i, false)
	_bake()


func restore_pillars() -> void:
	var changed := false
	for i in _pillars.size():
		if not _pillars[i].visible:
			_stand(i, true)
			changed = true
	if changed:
		_bake()


func _stand(i: int, up: bool) -> void:
	_pillars[i].visible = up
	_pillars[i].collision_layer = WALLS if up else 0
