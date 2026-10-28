extends Node
func _ready() -> void:
	var app = get_node("/root/App")
	await get_tree().create_timer(0.3, false).timeout
	Save.new_campaign("normal", 12345)
	app.clear_screens()
	app._begin_level(1, 0)
	for i in range(14):
		await get_tree().process_frame
	var g = app.game
	g.player.position = Vector2(200, 270)
	g.player.autofire = true
	var e = g.spawn_enemy("moth", Vector2(430, 270))
	print("KILL: dps=%.0f mult=%.2f hp=%.1f" % [g.player.attack_dps(), g.enemy_hp_mult(), e.max_hp])
	var t := 0.0
	var tot := false
	for i in range(300):
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if not is_instance_valid(e) or e.dead or e.hp <= 0.0:
			tot = true
			break
	if tot:
		print("KILL: tot nach %.2f s, kills=%d" % [t, g.stats.kills])
	else:
		print("KILL: lebt noch, hp=%.1f, bullets=%d" % [e.hp, g.bullets.player_bullets.size()])
	get_tree().quit(0)
