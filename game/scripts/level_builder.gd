class_name LevelBuilder
extends Node3D

# Builds a level from its description: floor, walls and pillars with collision, and the
# navigation mesh the AI walks on. It also answers the rules' questions about the place.
#
# What stands and where comes from the description alone. How it looks comes from the room
# pieces in assets/kit: each rectangle of floor or wall is laid with as many pieces as fit,
# stretched a little so they fill it exactly. Without the pieces it is drawn as grey boxes.

const GRID := preload("res://shaders/grid.gdshader")
const KIT := "res://assets/kit/"
# a unit's half-width, kept clear of walls by the navigation mesh
const AGENT_RADIUS := 0.5
# line of sight is judged at about chest height, so low kerbs and crates do not block it
const EYE := Vector3(0, 1.3, 0)
const KNEE := Vector3(0, 0.5, 0)
const WALLS := 1

# every room piece the builder may ask for
const PIECES := ["floor_tile_large", "wall", "barrier", "pillar", "box_large", "torch_mounted",
	"banner_patternA_blue", "banner_shield_white", "banner_patternB_green"]

## Draw the place with the room pieces. Off, it is the grey boxes with a metre grid.
@export var dressed := true
## How long a floor tile or a piece of wall is made, in metres, before it is fitted.
@export var piece_length := 2.4
## Walls lower than this are drawn as kerbs.
@export var kerb_below := 1.5
## Metres between the torches along a back wall.
@export var torch_every := 7.0
## The floor is painted a little darker and cooler than the walls, so that figures, rings and
## warnings stand out against it.
@export var floor_tint := Color(0.66, 0.74, 0.8)

var def: LevelDef

var _region: NavigationRegion3D
var _pillars: Array[StaticBody3D] = []
var _wall_mat: StandardMaterial3D
var _pillar_mat: StandardMaterial3D
var _kit_mat: StandardMaterial3D
var _floor_mat: StandardMaterial3D
var _pieces := {}  # piece name -> {"mesh": Mesh, "size": Vector3, "low": Vector3}, or null


func build(level: LevelDef) -> void:
	def = level
	_wall_mat = StandardMaterial3D.new()
	_wall_mat.albedo_color = Color(0.5, 0.52, 0.56)
	_pillar_mat = StandardMaterial3D.new()
	_pillar_mat.albedo_color = Color(0.44, 0.4, 0.36)
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = GRID
	# every piece is painted from the kit's one colour image
	if dressed and ResourceLoader.exists(KIT + "dungeon_texture.png"):
		_kit_mat = StandardMaterial3D.new()
		_kit_mat.albedo_texture = load(KIT + "dungeon_texture.png")
		_kit_mat.roughness = 1.0
		_floor_mat = _kit_mat.duplicate()
		_floor_mat.albedo_color = floor_tint

	for f in def.floors:
		if _lay_floor(f, 0.0):
			continue
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
		var block: BoxMesh = null
		if not _raise_wall(r, w.height):
			block = BoxMesh.new()
			block.size = box.size
		_solid(box, block, _wall_mat, Vector3(r.get_center().x, w.height / 2.0, r.get_center().y))

	for p in def.pillars:
		var round := CylinderShape3D.new()
		round.radius = p.r
		round.height = p.height
		var column: Mesh = null
		var stone := _piece("pillar")
		if stone.is_empty():
			var drum := CylinderMesh.new()
			drum.top_radius = p.r
			drum.bottom_radius = p.r
			drum.height = p.height
			drum.radial_segments = 20
			column = drum
		var body := _solid(round, column, _pillar_mat, p.pos + Vector3(0, p.height / 2.0, 0))
		if not stone.is_empty():
			# square, and a little inside the round shape that blocks the way
			var look := MeshInstance3D.new()
			look.mesh = stone.mesh
			look.material_override = _kit_mat
			look.scale = Vector3(p.r * 1.85 / stone.size.x, p.height / stone.size.y, p.r * 1.85 / stone.size.z)
			look.position.y = -p.height / 2.0
			body.add_child(look)
		body.set_meta("pillar", _pillars.size())
		_pillars.append(body)

	_region = NavigationRegion3D.new()
	add_child(_region)
	_bake()


# ---------- dressing the place with the room pieces

## The files the room pieces are in, for whoever wants them read before the level is built.
static func piece_files() -> Array[String]:
	var files: Array[String] = [KIT + "dungeon_texture.png"]
	for piece: String in PIECES:
		files.append(KIT + piece + ".glb")
	return files.filter(func(path: String) -> bool: return ResourceLoader.exists(path))


## One of each room piece, drawn singly at that spot, to be freed a few frames later. See
## Run.warm_up: a piece drawn alone and the same piece drawn in hundreds are two shaders.
func warm_up(at: Vector3) -> Array[Node]:
	var made: Array[Node] = []
	for name: String in PIECES:
		var piece := _piece(name)
		if piece.is_empty():
			continue
		var one := MeshInstance3D.new()
		one.mesh = piece.mesh
		one.material_override = _kit_mat
		one.scale = Vector3.ONE * 0.01
		add_child(one)
		one.global_position = at
		made.append(one)
		_copies(piece, [Transform3D(Basis.from_scale(Vector3.ONE * 0.01), at)])
		made.append(get_child(get_child_count() - 1))
	return made


# A room piece by name: its mesh, how big it is, and its lowest corner. Empty if there is none.
func _piece(piece: String) -> Dictionary:
	if _kit_mat == null:
		return {}
	if not _pieces.has(piece):
		_pieces[piece] = {}
		var path := KIT + piece + ".glb"
		if ResourceLoader.exists(path):
			var scene: Node = (load(path) as PackedScene).instantiate()
			var parts := scene.find_children("*", "MeshInstance3D", true, false)
			var part := (scene if scene is MeshInstance3D else parts[0] if not parts.is_empty() else null) as MeshInstance3D
			if part:
				var box := part.mesh.get_aabb()
				_pieces[piece] = {"mesh": part.mesh, "size": box.size, "low": box.position}
			scene.free()
	return _pieces[piece]


# Many copies of one piece, drawn as one thing.
func _copies(piece: Dictionary, places: Array[Transform3D], mat: Material = null) -> void:
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.mesh = piece.mesh
	many.instance_count = places.size()
	for i in places.size():
		many.set_instance_transform(i, places[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = many
	node.material_override = mat if mat else _kit_mat
	add_child(node)


# Lays tiles over a rectangle of floor, with their tops at that height.
func _lay_floor(f: Rect2, top: float) -> bool:
	var tile := _piece("floor_tile_large")
	if tile.is_empty() or f.size.x <= 0.0 or f.size.y <= 0.0:
		return false
	var nx := maxi(1, roundi(f.size.x / piece_length))
	var nz := maxi(1, roundi(f.size.y / piece_length))
	var step := Vector2(f.size.x / nx, f.size.y / nz)
	var grow := Vector3(step.x / tile.size.x, piece_length / tile.size.x, step.y / tile.size.z)
	var places: Array[Transform3D] = []
	for ix in nx:
		for iz in nz:
			var at := Vector3(f.position.x + (ix + 0.5) * step.x, top - (tile.low.y + tile.size.y) * grow.y, f.position.y + (iz + 0.5) * step.y)
			# every other tile is turned half round, so the pattern repeats less
			var turned := (ix * 7 + iz * 13) % 3 == 0
			places.append(Transform3D(Basis.from_scale(grow).rotated(Vector3.UP, PI if turned else 0.0), at))
	_copies(tile, places, _floor_mat)
	return true


# Draws a wall's box with pieces. A thin wall is one row of pieces, or of kerb if it is low; a
# small square one is a crate; a thick one is a ring of wall with a tiled top.
func _raise_wall(r: Rect2, tall: float) -> bool:
	var thin := minf(r.size.x, r.size.y)
	if maxf(r.size.x, r.size.y) <= 1.6:
		var crate := _piece("box_large")
		if crate.is_empty():
			return false
		var grow := Vector3(r.size.x / crate.size.x, tall / crate.size.y, r.size.y / crate.size.z)
		_copies(crate, [Transform3D(Basis.from_scale(grow), Vector3(r.get_center().x, 0, r.get_center().y))])
		return true
	var piece := _piece("barrier" if tall < kerb_below else "wall")
	if piece.is_empty():
		return false
	if thin <= 1.0:
		_row(piece, r, tall)
		if tall >= kerb_below and r.size.x > r.size.y:
			_hang(r, tall)
		return true
	var t := minf(0.6, thin / 2.0)
	_row(piece, Rect2(r.position.x, r.position.y, r.size.x, t), tall)
	_row(piece, Rect2(r.position.x, r.end.y - t, r.size.x, t), tall)
	_row(piece, Rect2(r.position.x, r.position.y + t, t, r.size.y - 2 * t), tall)
	_row(piece, Rect2(r.end.x - t, r.position.y + t, t, r.size.y - 2 * t), tall)
	_lay_floor(r.grow(-t * 0.5), tall - 0.06)
	return true


# One row of pieces filling a thin rectangle, along whichever way it is longer.
func _row(piece: Dictionary, r: Rect2, tall: float) -> void:
	var along_x := r.size.x >= r.size.y
	var length := r.size.x if along_x else r.size.y
	var thick := r.size.y if along_x else r.size.x
	if length <= 0.0 or thick <= 0.0:
		return
	var n := maxi(1, roundi(length / piece_length))
	var grow := Vector3(length / n / piece.size.x, tall / piece.size.y, thick / piece.size.z)
	var places: Array[Transform3D] = []
	for i in n:
		var along := (i + 0.5) * length / n
		var at := Vector3(r.position.x + along, 0, r.get_center().y) if along_x else Vector3(r.get_center().x, 0, r.position.y + along)
		places.append(Transform3D(Basis.from_scale(grow).rotated(Vector3.UP, 0.0 if along_x else PI / 2), at))
	_copies(piece, places)


# Torches and banners along the near face of a back wall. They are for show: nothing stands
# on the floor, so nothing is in the way.
func _hang(r: Rect2, tall: float) -> void:
	var torch := _piece("torch_mounted")
	var banners: Array[Dictionary] = []
	for b: String in PIECES.filter(func(piece: String) -> bool: return piece.begins_with("banner")):
		if not _piece(b).is_empty():
			banners.append(_piece(b))
	var n := int(r.size.x / torch_every)
	if n < 1:
		return
	var gap := r.size.x / n
	var torches: Array[Transform3D] = []
	var size := Basis.from_scale(Vector3.ONE * 1.3)
	for i in n:
		var x := r.position.x + (i + 0.5) * gap
		torches.append(Transform3D(size, Vector3(x, tall * 0.5, r.end.y)))
		if not banners.is_empty() and i + 1 < n:
			# a banner hangs half way to the next torch
			var banner := banners[i % banners.size()]
			var drop: float = tall * 0.92 - (banner.low.y + banner.size.y) * 0.7
			_copies(banner, [Transform3D(Basis.from_scale(Vector3.ONE * 0.7), Vector3(x + gap / 2, drop, r.end.y - banner.low.z * 0.7 + 0.02))])
	if not torch.is_empty():
		_copies(torch, torches)


func _solid(shape: Shape3D, mesh: Mesh, mat: Material, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = WALLS
	body.collision_mask = 0
	var hull := CollisionShape3D.new()
	hull.shape = shape
	body.add_child(hull)
	if mesh:
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
