extends CharacterBody3D
class_name Monster

var target
var campfire
var speed := 2.2
var health := 30.0
var attack_timer := 0.0
var is_bull := false

func _ready() -> void:
    var body := CollisionShape3D.new()
    var sh := CapsuleShape3D.new()
    sh.radius = 0.45
    sh.height = 1.8
    body.shape = sh
    body.position.y = 0.9
    add_child(body)
    var visual := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.8
    visual.mesh = mesh
    visual.position.y = 0.9
    visual.material_override = _mat(Color(0.13,0.12,0.14))
    add_child(visual)

func _physics_process(delta: float) -> void:
    if not target:
        return
    attack_timer -= delta
    var to_target := target.global_position - global_position
    if campfire and global_position.distance_to(campfire.global_position) < 10.0:
        to_target = campfire.global_position - global_position
        if global_position.distance_to(campfire.global_position) < 9.0:
            velocity = Vector3.ZERO
            return
    to_target.y = 0
    if to_target.length() > 2.0:
        velocity = to_target.normalized() * speed
        look_at(global_position + velocity, Vector3.UP)
    else:
        velocity = Vector3.ZERO
        if attack_timer <= 0:
            target.health = max(0.0, target.health - (12.0 if is_bull else 6.0))
            attack_timer = 1.2
    move_and_slide()

func player_hit(player) -> void:
    health -= 20.0 if player.has_red_axe else 10.0
    if health <= 0:
        queue_free()

func _mat(c: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    return m
