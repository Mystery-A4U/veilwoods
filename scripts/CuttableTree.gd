extends Node3D
class_name CuttableTree

var world
var tree_root
var hits_left := 6

func setup(w, root, hits: int) -> void:
    world = w
    tree_root = root
    hits_left = hits

func player_hit(player) -> void:
    hits_left -= 1
    if hits_left <= 0:
        player.add_wood(3 if hits_left <= -1 else 2)
        if world:
            world.trees.erase(tree_root)
        tree_root.queue_free()
    else:
        player.add_wood(1)
