## v5 BB6 — Plunge Strike landing shockwave (Amaro, aerial-only).
## AbilityState dives the caster (CasterMotion.PLUNGE); on landing it spawns
## this effect at the caster's feet: a small AoE (RADIUS) with damage + stagger
## and the shared blast ring/flash (blast_vfx.spawn). Damage uses
## blast_vfx.detonate (once per enemy, flat radius).
extends Node3D

const BlastVFX := preload("res://src/effects/blast_vfx.gd")

const RADIUS := 3.0

var hit_count: int = 0


func setup(caster: Node3D, _target: Node3D, ability: AbilityData, _aim_dir: Vector3) -> void:
	global_position = caster.global_position + Vector3(0, 0.5, 0)
	var damage: float = ability.damage if ability else 30.0
	var stagger: float = ability.stagger if ability else 25.0
	BlastVFX.spawn(get_parent(), global_position, RADIUS)
	hit_count = BlastVFX.detonate(caster, caster.global_position, RADIUS, damage, stagger)
	Events.camera_shake_requested.emit(0.25, 0.18)
	# Linger one frame for tests, then free (the BlastVFX node frees itself).
	get_tree().create_timer(0.05).timeout.connect(queue_free)
