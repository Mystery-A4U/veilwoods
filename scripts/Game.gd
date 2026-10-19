extends Node3D
## VEILWOODS - procedural game bootstrap.
## All prototype geometry is generated at runtime so the project has zero external asset dependencies.

const PlayerScript = preload("res://scripts/Player.gd")
const WorldScript = preload("res://scripts/World.gd")
const UIScript = preload("res://scripts/UI.gd")

var world
var player
var ui

func _ready() -> void:
    _setup_environment()
    world = WorldScript.new()
    world.name = "World"
    add_child(world)

    player = PlayerScript.new()
    player.name = "Player"
    add_child(player)
    player.global_position = Vector3(0, 2.0, 22)

    ui = UIScript.new()
    ui.name = "UI"
    add_child(ui)
    ui.bind_game(self)

    world.bind_game(self)

func _process(delta: float) -> void:
    if world:
        world.tick(delta)
    if player:
        player.game_ref = self

func _setup_environment() -> void:
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color(0.055, 0.075, 0.06)
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.58, 0.68, 0.58)
    e.ambient_light_energy = 0.8
    e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.environment = e
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.name = "Sun"
    sun.rotation_degrees = Vector3(-48, -25, 0)
    sun.light_energy = 1.15
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 70.0
    add_child(sun)
    world_sun = sun

var world_sun: DirectionalLight3D
