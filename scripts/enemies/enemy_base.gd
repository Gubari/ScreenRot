extends CharacterBody2D
class_name EnemyBase

signal enemy_killed(pos: Vector2, enemy_type: String)

@export var max_hp: int = 1
@export var move_speed: float = 80.0
@export var contact_damage: int = 1
@export var score_value: int = 10
@export var enemy_type: String = "grunt"

var current_hp: int
var player: Node2D = null
var touching_player: bool = false
var contact_tick_timer: float = 0.0
@export var contact_tick_rate: float = 0.5  # damage every 0.5s while touching

func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemies")
	await get_tree().process_frame
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if spr:
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(delta: float) -> void:
	if player and is_instance_valid(player) and player.visible:
		do_movement(delta)
		move_and_slide()
		# Continuous contact damage
		if touching_player:
			contact_tick_timer -= delta
			if contact_tick_timer <= 0:
				contact_tick_timer = contact_tick_rate
				if player.has_method("take_damage"):
					player.take_damage(contact_damage)

func do_movement(_delta: float) -> void:
	# Override in subclasses
	var dir = (player.global_position - global_position).normalized()
	velocity = dir * move_speed

func take_damage(amount: int) -> void:
	current_hp -= amount
	flash_white()
	AudioManager.play_sfx("enemy_hit")
	if current_hp <= 0:
		die()

func flash_white() -> void:
	modulate = Color(5, 5, 5, 1)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

func die() -> void:
	AudioManager.play_sfx("enemy_kill")
	enemy_killed.emit(global_position, enemy_type)
	# Give score to player
	if player and player.has_method("add_score"):
		player.add_score(score_value)
	queue_free()

func _on_hit_player(body: Node2D) -> void:
	if body.is_in_group("player"):
		touching_player = true
		contact_tick_timer = 0.0  # Damage immediately on first contact
		if body.has_method("take_damage"):
			body.take_damage(contact_damage)

func _on_hit_player_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		touching_player = false
