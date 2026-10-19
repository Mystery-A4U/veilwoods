extends CanvasLayer
## Lightweight UI + mobile controls. Uses built-in controls only.

var game
var hud: Label
var stats: Label
var hint: Label
var joystick_base: ColorRect
var joystick_knob: ColorRect
var move_touch_id := -1
var look_touch_id := -1
var move_start := Vector2.ZERO
var last_look := Vector2.ZERO

func bind_game(g) -> void:
    game = g
    _build()

func _build() -> void:
    hud = Label.new()
    hud.position = Vector2(24,20)
    hud.add_theme_font_size_override("font_size",24)
    hud.text = "VEILWOODS"
    add_child(hud)

    stats = Label.new()
    stats.position = Vector2(24,58)
    stats.add_theme_font_size_override("font_size",16)
    add_child(stats)

    hint = Label.new()
    hint.position = Vector2(24,104)
    hint.add_theme_font_size_override("font_size",14)
    hint.text = "WASD • Mouse • E Interact • LMB Chop/Attack • Shift Sprint"
    add_child(hint)

    joystick_base = ColorRect.new()
    joystick_base.position = Vector2(35,520)
    joystick_base.size = Vector2(150,150)
    joystick_base.color = Color(1,1,1,0.10)
    add_child(joystick_base)

    joystick_knob = ColorRect.new()
    joystick_knob.position = Vector2(85,570)
    joystick_knob.size = Vector2(50,50)
    joystick_knob.color = Color(1,1,1,0.28)
    add_child(joystick_knob)

    var interact := Button.new()
    interact.text = "INTERACT"
    interact.position = Vector2(1060,590)
    interact.size = Vector2(170,60)
    interact.pressed.connect(_interact)
    add_child(interact)

    var upgrade := Button.new()
    upgrade.text = "CAMPFIRE\nUPGRADE"
    upgrade.position = Vector2(1060,510)
    upgrade.size = Vector2(170,65)
    upgrade.pressed.connect(_upgrade)
    add_child(upgrade)

    var attack := Button.new()
    attack.text = "AXE / ATTACK"
    attack.position = Vector2(870,590)
    attack.size = Vector2(170,60)
    attack.pressed.connect(_attack)
    add_child(attack)

func _process(_delta: float) -> void:
    if not game or not game.player or not game.world:
        return
    stats.text = "DAY %02d  •  %s\nHP %d  Hunger %d  Thirst %d\nWood %d  Berries %d  Medicine %d\nTool: %s  •  Campfire Lv.%d" % [
        game.world.day, _clock(game.world.time_of_day),
        game.player.health, game.player.hunger, game.player.thirst,
        game.player.wood, game.player.berries, game.player.medicine,
        game.player.selected_tool, game.world.campfire_level
    ]

func _clock(t: float) -> String:
    var h := int(t)
    var m := int((t - h) * 60.0)
    return "%02d:%02d" % [h,m]

func _interact() -> void:
    if game.player:
        game.player._interact_or_attack()

func _attack() -> void:
    if game.player:
        game.player._interact_or_attack()

func _upgrade() -> void:
    if game.world:
        game.world.upgrade_campfire()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x < 250 and event.position.y > 430:
                move_touch_id = event.index
                move_start = event.position
                joystick_knob.position = event.position - Vector2(25,25)
            elif event.position.x > 300:
                look_touch_id = event.index
                last_look = event.position
        else:
            if event.index == move_touch_id:
                move_touch_id = -1
                joystick_knob.position = Vector2(85,570)
                game.player.set_mobile_move(Vector2.ZERO)
            if event.index == look_touch_id:
                look_touch_id = -1
    elif event is InputEventScreenDrag:
        if event.index == move_touch_id:
            var delta := (event.position - move_start) / 65.0
            delta = delta.limit_length(1.0)
            joystick_knob.position = move_start + delta*65.0 - Vector2(25,25)
            game.player.set_mobile_move(Vector2(delta.x, delta.y))
        elif event.index == look_touch_id:
            var delta := event.position - last_look
            last_look = event.position
            game.player.add_mobile_look(delta)
