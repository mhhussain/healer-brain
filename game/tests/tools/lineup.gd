extends SceneTree

# A developer tool, not a test: stands the whole cast in two rows under the game's camera angle
# and light, each playing one clip, so that --write-movie can record frames to look at. From
# the repo root:
#   godot --path game -s tests/tools/lineup.gd --write-movie "$PWD/build/shots/l.png" --fixed-fps 60 --quit-after 40 -- attack 15 0
# The last words are the clip (idle if left out), how many metres tall the view is, and how far
# the figures are turned away from the camera, in degrees.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var clip: String = args[0] if args.size() > 0 else "idle"
	var stage: Node3D = load("res://scenes/run.tscn").instantiate()
	# only the light, the sky and the camera angle are wanted, not a run
	stage.set_script(null)
	for child in stage.get_children():
		if not (child is WorldEnvironment or child is DirectionalLight3D):
			child.free()
	root.add_child(stage)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(args[1]) if args.size() > 1 else 15.0
	cam.rotation_degrees = Vector3(-45, -45, 0)
	stage.add_child(cam)
	cam.position = Vector3(0, 1.4, 0) + cam.basis.z * 40.0
	cam.current = true
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(80, 80)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.36, 0.38, 0.4)
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.material_override = floor_mat
	stage.add_child(floor_node)

	var across := cam.basis.x
	var back := Vector3(across.z, 0, -across.x)
	var heroes: Array = Heroes.ALL
	_turn = float(args[2]) if args.size() > 2 else 0.0
	_row(stage, heroes, across, back * -2.6, clip)
	var enemies := ["hatchling", "hexer", "shaman", "archer", "brute", "berserker", "overseer", "krogg", "velisse", "sulmar"]
	_row(stage, enemies, across, back * 2.4, clip)


var _turn := 0.0


func _row(stage: Node3D, ids: Array, across: Vector3, at: Vector3, clip: String) -> void:
	var widths: Array = ids.map(func(id: String) -> float: return 3.6 if id in ["krogg", "velisse", "sulmar"] else 2.3)
	var total: float = widths.reduce(func(a: float, b: float) -> float: return a + b, 0.0)
	var x := -total / 2.0
	for i in ids.size():
		x += widths[i] / 2.0
		var scene := Figures.scene_for(ids[i])
		if scene:
			var figure: Node3D = scene.instantiate()
			stage.add_child(figure)
			figure.position = at + across * x
			figure.rotation_degrees.y = -45 + _turn
			var player := figure.find_child("AnimationPlayer") as AnimationPlayer
			if player and player.has_animation(clip):
				player.play(clip)
		x += widths[i] / 2.0
