extends StaticBody3D
class_name Chest

var world
var opened := false

func _ready() -> void:
    var mesh := BoxMesh.new()
    mesh.size = Vector3(1.3,0.8,0.9)
    var n := MeshInstance3D.new()
    n.mesh = mesh
    n.material_override = _mat(Color(0.28,0.13,0.05))
    add_child(n)
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = Vector3(1.3,0.8,0.9)
    cs.shape = sh
    add_child(cs)

func _mat(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    return m

func interact(player) -> void:
    if opened:
        return
    opened = true
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    player.add_wood(rng.randi_range(3,8))
    if rng.randf() < 0.25:
        player.give_red_axe()
    if world:
        world.monsters = world.monsters
    scale.y = 0.55
