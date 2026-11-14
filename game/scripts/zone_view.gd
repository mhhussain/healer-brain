extends Node3D

# Draws the telegraphed zones on the floor: a faint outline of where it will land, and a brighter
# patch that grows to fill it as the time runs out.

@export var run: Run

const RED := Color("ef5d4a")

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
		var k := clampf(z.t / z.delay, 0.0, 1.0)
		node.get_child(1).scale = Vector3(k, 1, k)
	for z: Zone in _shown.keys():
		if not live.has(z):
			_shown[z].queue_free()
			_shown.erase(z)


func _make(z: Zone) -> Node3D:
	var node := Node3D.new()
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(node)
	node.global_position = Vector3(z.pos.x, 0.03, z.pos.z)
	var mesh := _fan(z)
	node.add_child(_patch(mesh, Color(RED, 0.2), 0.0))
	node.add_child(_patch(mesh, Color(RED, 0.4), 0.01))
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


# A flat fan of triangles: the whole circle, or the slice a cone covers.
func _fan(z: Zone) -> ArrayMesh:
	var half := PI if z.kind == "circle" else z.half
	var mid := 0.0 if z.kind == "circle" else atan2(z.dir.z, z.dir.x)
	var steps := maxi(6, ceili(half * 2.0 / 0.12))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in steps:
		var a := mid - half + 2.0 * half * i / steps
		var b := mid - half + 2.0 * half * (i + 1) / steps
		# wound so that the face looks up
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a), 0, sin(a)) * z.r)
		st.add_vertex(Vector3(cos(b), 0, sin(b)) * z.r)
	return st.commit()
