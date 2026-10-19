extends CharacterBody3D
## First-person controller for desktop and mobile.

var game_ref
var camera: Camera3D
var head: Node3D
var speed := 4.8
var sprint_speed := 7.0
var gravity := 16.0
var look_sensitivity := 0.12
var mobile_look := Vector2.ZERO
var mobile_move := Vector2.ZERO
var pitch := -8.0
var health := 100.0
var hunger := 100.0
var thirst := 100.0
var selected_tool := "Axe"
var has_red_axe := false
var wood := 0
var berries := 0
var medicine := 0
var meat := 0

func _ready() -> void:
    collision_layer = 1
    collision_mask = 1
    _build_body()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_body() -> void:
    var shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.35
    capsule.height = 1.8
    shape.shape = capsule
    shape.position.y = 0.9
    add_child(shape)

    head = Node3D.new()
    head.name = "Head"
    head.position = Vector3(0, 1.62, 0)
    add_child(head)

    camera = Camera3D.new()
    camera.current = true
    camera.fov = 75
    camera.near = 0.05
    camera.far = 130.0
    head.add_child(camera)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        _look(event.relative)
    if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        _interact_or_attack()

func _physics_process(delta: float) -> void:
    var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    if mobile_move.length() > 0.1:
        input_vec = mobile_move
    var basis := global_transform.basis
    var dir := (basis * Vector3(input_vec.x, 0, input_vec.y)).normalized()
    var current_speed := sprint_speed if Input.is_action_pressed("sprint") else speed
    velocity.x = dir.x * current_speed
    velocity.z = dir.z * current_speed
    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = -0.2
    move_and_slide()
    hunger = max(0.0, hunger - delta * 0.012)
    thirst = max(0.0, thirst - delta * 0.02)

func _look(relative: Vector2) -> void:
    rotate_y(deg_to_rad(-relative.x * look_sensitivity))
    pitch = clamp(pitch - relative.y * look_sensitivity, -85.0, 80.0)
    head.rotation_degrees.x = pitch

func set_mobile_move(v: Vector2) -> void:
    mobile_move = v

func add_mobile_look(v: Vector2) -> void:
    _look(v)

func _interact_or_attack() -> void:
    if not camera:
        return
    var from := camera.global_position
    var to := from + -camera.global_transform.basis.z * 3.2
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.collision_mask = 1
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit:
        var obj = hit.get("collider")
        if obj and obj.has_method("player_hit"):
            obj.player_hit(self)
        elif obj and obj.has_method("interact"):
            obj.interact(self)

func give_red_axe() -> void:
    has_red_axe = true
    selected_tool = "Red Axe"

func add_wood(amount: int) -> void:
    wood += amount

func add_berry(amount: int) -> void:
    berries += amount

func add_medicine(amount: int) -> void:
    medicine += amount
