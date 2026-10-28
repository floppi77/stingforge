extends Node
## Rechnet aus den Leveldaten aus, wie viele Punkte ein Level höchstens bringt:
## geplante Wellen × Gegnerwert + Nektar-Umrechnung + Bossprämie.

func _ready() -> void:
	var diff: Dictionary = Data.DIFFICULTY["normal"]
	var spawn_mult := float(diff.spawn_mult)
	var score_mult := float(diff.score_mult)
	var total := 0
	print("LVL  Wellen  Gegner  Kampfpunkte  Nektar  Boss   Summe")
	for lv in Data.levels:
		var sec_sum := 0.0
		var enemies := 0.0
		var nectar := 0.0
		var idx := 0
		for sec in lv.sections:
			var dur := float(sec.dur)
			var interval := clampf(4.2 / spawn_mult, 2.4, 99.0)
			var spawns := dur / interval
			var pools: Array = sec.pools
			# Erwartungswert über beide Pools und alle Formationen darin
			var e_cnt := 0.0
			var e_n := 0.0
			var e_nectar := 0.0
			var entries := 0
			for pool in pools:
				for fname in pool:
					var f: Dictionary = Director.FORMATIONS.get(String(fname), {})
					if f.is_empty():
						continue
					var en := Data.enemy(String(f.enemy))
					var n := float(f.get("n", 1))
					e_cnt += float(en.get("score", 0)) * n
					e_nectar += float(en.get("nectar", 0)) * n
					e_n += n
					entries += 1
			if entries == 0:
				continue
			e_cnt /= float(entries)
			e_nectar /= float(entries)
			e_n /= float(entries)
			# ab Abschnitt 3 kommt mit 35% Wahrscheinlichkeit eine zweite Welle
			var extra := 1.35 if idx >= 2 else 1.0
			sec_sum += spawns * e_cnt * extra
			enemies += spawns * e_n * extra
			nectar += spawns * e_nectar * extra
			idx += 1
		# Miniboss: ein starker Gegner
		var mini: Dictionary = lv.get("miniboss", {})
		if not mini.is_empty():
			var me := Data.enemy(String(mini.get("enemy", "")))
			sec_sum += float(me.get("score", 0)) * float(mini.get("hp_mult", 1.0))
			enemies += 1.0
			nectar += float(me.get("nectar", 0)) * 3.0
		var boss_gain := 3000.0 + float(lv.id) * 500.0
		var conv := nectar * 10.0
		var summe := (sec_sum + boss_gain + conv) * score_mult
		total += int(summe)
		print("%3d %6.0f %7.0f %12.0f %7.0f %6.0f %7.0f" % [int(lv.id),
			(sec_sum + boss_gain) / 4.2, enemies, (sec_sum + boss_gain) * score_mult,
			conv * score_mult, boss_gain * score_mult, summe])
	print("GESAMT %d Punkte" % total)
	print("PUNKTE_OK")
	get_tree().quit(0)
