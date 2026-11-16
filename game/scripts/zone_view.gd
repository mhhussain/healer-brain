extends Node3D

# Draws the telegraphed zones on the floor: a faint outline of where it will land, and a brighter
# patch that grows to fill it as the time runs out. A zone that stays after it lands keeps its
# patch, in amber; a place to shelter is gold from the start.

@export var run: Run

const RED := Color("ef5d4a")
const AMBER := Color("f08a3c")
const GOLD := Color("f0d27a")

var _shown := {}  # Zone -> Node3D


func _process(_delta: float) -> void:
	if run == null or run.combat == null:
		return
	var live := {}
	for z in run.combat.zones:
		live[z] = true
		var node: Node3D = _shown.get(z)
		if node == null:
			node = _make(z)
			_shown[z] = node
		# one that moves with a unit or turns is put where it is now
		node.global_position = Vector3(z.pos.x, 0.03, z.pos.z)
		if z.kind != "circle":
			node.rotation.y = -atan2(z.dir.z, z.dir.x)
		var k := 1.0 if z.safe or z.went else clampf(z.t / z.delay, 0.0, 1.0)
		var fill: MeshInstance3D = node.get_child(1)
		# a lane fills along its length, the others from their middle
		fill.scale = Vector3(k, 1, 1) if z.kind == "lane" else Vector3(k, 1, k)
		if z.went and not node.has_meta("went"):
			node.set_meta("went", true)
			(fill.material_override as StandardMaterial3D).albedo_color = Color(AMBER, 0.45)
	for z: Zone in _shown.keys():
		if not live.has(z):
			_shown[z].queue_free()
			_shown.erase(z)


func _make(z: Zone) -> Node3D:
	var node := Node3D.new()
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(node)
	var mesh := _strip(z) if z.kind == "lane" else _fan(z)
	var color := GOLD if z.safe else RED
	node.add_child(_patch(mesh, Color(color, 0.2), 0.0))
	node.add_child(_patch(mesh, Color(color, 0.4), 0.01))
	return node


# The material has the same settings as every other effect and the shadows under the units, so
# the engine already has its shader. A setting of its own (drawing both faces, say) would make
# the engine build a new shader each time a zone appeared, and the game would freeze while it did.
func _patch(mesh: Mesh, color: Color, lift: float) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	var patch := MeshInstance3D.new()
	patch.mesh = mesh
	patch.material_override = mat
	patch.position.y = lift
	return patch


# A flat fan of triangles: the whole circle, or the slice a cone covers. It is made pointing
# along +x, and the node is turned to the way the zone points.
func _fan(z: Zone) -> ArrayMesh:
	var half := PI if z.kind == "circle" else z.half
	var steps := maxi(6, ceili(half * 2.0 / 0.12))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in steps:
		var a := -half + 2.0 * half * i / steps
		var b := -half + 2.0 * half * (i + 1) / steps
		# wound so that the face looks up
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a), 0, sin(a)) * z.r)
		st.add_vertex(Vector3(cos(b), 0, sin(b)) * z.r)
	return st.commit()


# A lane: a long strip along +x, `r` each way from the middle and `half` to each side.
func _strip(z: Zone) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-z.r, 0, -z.half)
	var b := Vector3(z.r, 0, -z.half)
	var c := Vector3(z.r, 0, z.half)
	var d := Vector3(-z.r, 0, z.half)
	for v: Vector3 in [a, b, c, a, c, d]:
		st.add_vertex(v)
	return st.commit()
