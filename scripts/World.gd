extends Node3D
const CuttableTree = preload("res://scripts/CuttableTree.gd")
const Chest = preload("res://scripts/Chest.gd")
const Monster = preload("res://scripts/Monster.gd")
## Procedural low-poly island, town, forest, resources, campfire, enemies and boss.

var game
var day := 1
var time_of_day := 8.0
var day_length := 150.0
var campfire_level := 1
var wood_required := [0, 8, 16, 28, 44, 64]
var campfire: Node3D
var camp_light: OmniLight3D
var sun: DirectionalLight3D
var rng := RandomNumberGenerator.new()
var trees := []
var monsters := []
var boss_spawned := false
var emerald_spawned := false

func _ready() -> void:
    rng.seed = 240519
    _make_world()

func bind_game(g) -> void:
    game = g

func tick(delta: float) -> void:
    time_of_day += delta * 24.0 / day_length
    if time_of_day >= 24.0:
        time_of_day -= 24.0
        day += 1
        if day > 50:
            day = 50
    _update_lighting()
    _spawn_night_enemies()

func _make_world() -> void:
    _make_ground()
    _make_town()
    _make_forest()
    _make_campfire()
    _make_chests()
    _make_landmarks()

func _mat(color: Color, rough := 0.9, emission := Color(0,0,0)) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    if emission != Color(0,0,0):
        m.emission_enabled = true
        m.emission = emission
        m.emission_energy_multiplier = 2.5
    return m

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, collision := true) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var n := MeshInstance3D.new()
    n.mesh = mesh
    n.position = pos
    n.material_override = _mat(color)
    parent.add_child(n)
    if collision:
        var body := StaticBody3D.new()
        body.position = pos
        var cs := CollisionShape3D.new()
        var sh := BoxShape3D.new()
        sh.size = size
        cs.shape = sh
        body.add_child(cs)
        parent.add_child(body)
    return n

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, collision := true) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 8
    var n := MeshInstance3D.new()
    n.mesh = mesh
    n.position = pos
    n.material_override = _mat(color)
    parent.add_child(n)
    if collision:
        var body := StaticBody3D.new()
        body.position = pos
        var cs := CollisionShape3D.new()
        var sh := CylinderShape3D.new()
        sh.radius = radius
        sh.height = height
        cs.shape = sh
        body.add_child(cs)
        parent.add_child(body)
    return n

func _make_ground() -> void:
    _box(self, Vector3(0,-0.6,0), Vector3(110,1,110), Color(0.18,0.38,0.16))
    # shoreline rocks / boundary
    for i in range(40):
        var a := TAU * i / 40.0
        var p := Vector3(cos(a)*52.0, 0, sin(a)*52.0)
        _cylinder(self, p + Vector3(0,0.35,0), 1.0 + rng.randf(), 0.7, Color(0.28,0.30,0.27), false)

func _make_town() -> void:
    var town := Node3D.new()
    town.name = "Town"
    add_child(town)
    # road
    _box(town, Vector3(0,0.02,8), Vector3(46,0.08,5), Color(0.28,0.25,0.20), false)
    _box(town, Vector3(10,0.03,-3), Vector3(5,0.09,38), Color(0.28,0.25,0.20), false)
    var buildings = [
        ["House A", Vector3(-15,2,8), Vector3(7,4,6), Color(0.58,0.38,0.22)],
        ["House B", Vector3(-15,2,-2), Vector3(7,4,6), Color(0.46,0.30,0.20)],
        ["Meat Shop", Vector3(0,2,1), Vector3(7,4,6), Color(0.45,0.20,0.18)],
        ["Vegetable Shop", Vector3(18,2,6), Vector3(7,4,6), Color(0.25,0.42,0.18)],
        ["Market", Vector3(18,2,-6), Vector3(8,4,7), Color(0.40,0.34,0.18)],
        ["Hospital", Vector3(2,2,-12), Vector3(10,4,7), Color(0.82,0.82,0.76)],
        ["House C", Vector3(-15,2,-12), Vector3(7,4,6), Color(0.33,0.40,0.45)]
    ]
    for b in buildings:
        _building(town, b[0], b[1], b[2], b[3])

func _building(parent: Node3D, label: String, pos: Vector3, size: Vector3, color: Color) -> void:
    var b := Node3D.new()
    b.name = label
    parent.add_child(b)
    _box(b, pos, size, color)
    _box(b, pos + Vector3(0,size.y/2+0.35,0), Vector3(size.x+0.5,0.7,size.z+0.5), Color(0.16,0.10,0.08), false)
    _box(b, pos + Vector3(0,0,-size.z/2-0.03), Vector3(1.5,1.7,0.12), Color(0.10,0.18,0.22), false)
    if label == "Hospital":
        _box(b, pos + Vector3(0,0.4,size.z/2+0.04), Vector3(3.0,0.5,0.12), Color(0.92,0.92,0.90), false)

func _make_forest() -> void:
    var forest := Node3D.new()
    forest.name = "DeepForest"
    add_child(forest)
    for i in range(115):
        var angle := rng.randf_range(0, TAU)
        var radius := rng.randf_range(22, 49)
        var p := Vector3(cos(angle)*radius, 0, sin(angle)*radius)
        if p.distance_to(Vector3(0,0,0)) < 22:
            continue
        var large := i % 4 == 0
        _tree(forest, p, large)
    for i in range(75):
        var p := Vector3(rng.randf_range(-48,48),0,rng.randf_range(-48,48))
        if abs(p.x) < 24 and abs(p.z) < 20:
            continue
        _plant(forest, p, i % 3)

func _tree(parent: Node3D, p: Vector3, large: bool) -> void:
    var t := Node3D.new()
    t.name = "CuttableTree"
    t.position = p
    t.set_meta("cuttable", true)
    parent.add_child(t)
    var trunk_h := 5.5 if large else 3.2
    _cylinder(t, Vector3(0,trunk_h/2,0), 0.48 if large else 0.30, trunk_h, Color(0.30,0.18,0.09))
    var crown := SphereMesh.new()
    crown.radius = 2.3 if large else 1.45
    crown.height = 4.0 if large else 2.6
    var leaf := MeshInstance3D.new()
    leaf.mesh = crown
    leaf.position = Vector3(0,trunk_h+1.2,0)
    leaf.material_override = _mat(Color(0.10,0.30,0.12))
    t.add_child(leaf)
    var body := StaticBody3D.new()
    var cs := CollisionShape3D.new()
    var sh := CylinderShape3D.new()
    sh.radius = 0.55
    sh.height = trunk_h
    cs.shape = sh
    cs.position.y = trunk_h/2
    body.add_child(cs)
    t.add_child(body)
    var script_node := CuttableTree.new()
    script_node.setup(self, t, 10 if large else 6)
    t.add_child(script_node)
    trees.append(t)

func _plant(parent: Node3D, p: Vector3, kind: int) -> void:
    var n := Node3D.new()
    n.position = p
    parent.add_child(n)
    if kind == 0:
        for j in range(4):
            _box(n, Vector3((j-1.5)*0.12,0.18,0), Vector3(0.08,0.35,0.28), Color(0.12,0.42,0.12), false)
    elif kind == 1:
        _cylinder(n, Vector3(0,0.2,0), 0.28, 0.4, Color(0.20,0.48,0.16), false)
        for j in range(3):
            var berry := _cylinder(n, Vector3((j-1)*0.14,0.48,0), 0.08, 0.16, Color(0.72,0.08,0.06), false)
    else:
        _cylinder(n, Vector3(0,0.22,0), 0.18, 0.44, Color(0.22,0.56,0.22), false)
    n.set_meta("resource", "berry" if kind == 1 else "medicine")

func _make_campfire() -> void:
    campfire = Node3D.new()
    campfire.name = "Campfire"
    campfire.position = Vector3(0,0,22)
    add_child(campfire)
    for i in range(8):
        var a := TAU * i / 8.0
        _cylinder(campfire, Vector3(cos(a)*1.0,0.3,sin(a)*1.0), 0.22, 2.1, Color(0.30,0.18,0.08), false).rotation_degrees.z = 90
    var flame := _cylinder(campfire, Vector3(0,1.0,0), 0.45, 1.5, Color(1.0,0.35,0.05), false)
    flame.material_override = _mat(Color(1,0.24,0.03),0.4,Color(1,0.12,0.01))
    camp_light = OmniLight3D.new()
    camp_light.light_color = Color(1.0,0.55,0.20)
    camp_light.light_energy = 5.0
    camp_light.omni_range = 12.0
    camp_light.position.y = 2.0
    campfire.add_child(camp_light)

func upgrade_campfire() -> bool:
    if campfire_level >= 6 or not game or not game.player:
        return false
    var cost := wood_required[campfire_level]
    if game.player.wood < cost:
        return false
    game.player.wood -= cost
    campfire_level += 1
    camp_light.omni_range = 12.0 + campfire_level * 3.5
    camp_light.light_energy = 5.0 + campfire_level
    return true

func _make_chests() -> void:
    for i in range(8):
        var p := Vector3(rng.randf_range(-40,40),0.5,rng.randf_range(-40,40))
        if p.distance_to(Vector3(0,0,0)) < 25:
            continue
        var c := Chest.new()
        c.position = p
        c.name = "LootChest"
        add_child(c)
        c.world = self

func _make_landmarks() -> void:
    var shrine := Node3D.new()
    shrine.name = "EmeraldShrine"
    shrine.position = Vector3(-35,0,-35)
    add_child(shrine)
    _box(shrine, Vector3(0,0.4,0), Vector3(5,0.8,5), Color(0.18,0.18,0.20))
    var gem := _cylinder(shrine, Vector3(0,2,0), 0.75, 2.2, Color(0.05,0.8,0.45), false)
    gem.material_override = _mat(Color(0.03,0.8,0.42),0.2,Color(0.0,0.7,0.3))
    gem.visible = false
    shrine.set_meta("emerald", gem)

func _update_lighting() -> void:
    if not game or not game.world_sun:
        return
    var night := time_of_day < 6.0 or time_of_day >= 19.0
    var t := sin((time_of_day - 6.0) / 24.0 * TAU) * 0.5 + 0.5
    game.world_sun.light_energy = lerp(0.18,1.2,t)
    game.world_sun.rotation_degrees.x = lerp(-15.0,-55.0,t)
    if night:
        game.world_sun.light_color = Color(0.25,0.34,0.55)
    else:
        game.world_sun.light_color = Color(1.0,0.95,0.82)

func _spawn_night_enemies() -> void:
    var night := time_of_day < 5.5 or time_of_day >= 20.0
    if night and monsters.size() < 5 and game and game.player:
        for i in range(2):
            var p := game.player.global_position + Vector3(rng.randf_range(-22,22),0,rng.randf_range(-22,22))
            if p.distance_to(campfire.global_position) < camp_light.omni_range + 5:
                continue
            var m := Monster.new()
            m.position = p
            m.target = game.player
            m.campfire = campfire
            add_child(m)
            monsters.append(m)
    if not night:
        for m in monsters:
            if is_instance_valid(m):
                m.queue_free()
        monsters.clear()
