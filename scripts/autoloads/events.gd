## Signal bus for cross-system communication.
## Systems communicate via signals here rather than direct references.
extends Node

# --- Player ---
signal player_spawned(player: CharacterBody3D)
signal player_died
signal player_respawned
signal player_hp_changed(current: float, maximum: float)
signal player_mp_changed(current: float, maximum: float)
signal player_atb_changed(current: float, maximum: float)
signal player_hurt(damage: float, source: Node3D)
signal player_healed(amount: float)

# --- Combat ---
signal combat_started
signal combat_ended
signal combo_count_changed(count: int)
signal combo_reset
signal attack_hit(target: Node3D, damage: float)
signal hit_stop_requested(duration: float)
signal camera_shake_requested(intensity: float, duration: float)

# --- Lock-On ---
signal lock_on_target_acquired(target: Node3D)
signal lock_on_target_lost
signal lock_on_target_switched(new_target: Node3D)

# --- Tactical Mode ---
signal tactical_mode_entered
signal tactical_mode_exited
signal tactical_command_selected(ability_data: Resource)
signal tactical_command_executed(ability_data: Resource)
signal tactical_slot_changed(index: int)
signal tactical_category_changed(category: int)
signal tactical_phase_changed(phase: int)
signal tactical_target_info(ability_name: String, target_names: PackedStringArray, selected_index: int)

# --- Enemy ---
signal enemy_spawned(enemy: Node3D)
signal enemy_died(enemy: Node3D)
signal enemy_damaged(enemy: Node3D, damage: float)
signal enemy_aggro_triggered(enemy: Node3D)

# --- Abilities ---
signal ability_cast_started(ability_data: Resource)
signal ability_cast_completed(ability_data: Resource)
signal ability_cast_interrupted(ability_data: Resource)
signal ability_cooldown_started(ability_id: StringName, duration: float)
signal ability_cooldown_finished(ability_id: StringName)
signal ability_request_failed(reason: String, ability_data: Resource)
signal ability_effect_spawned(effect: Node3D, ability_data: Resource)

# --- Inventory / Equipment ---
signal item_acquired(item_data: Resource, quantity: int)
signal item_used(item_data: Resource)
signal equipment_changed(slot: int, old_item: Resource, new_item: Resource)

# --- Quest ---
signal quest_accepted(quest_id: StringName)
signal quest_completed(quest_id: StringName)
signal quest_objective_updated(quest_id: StringName, objective_index: int)

# --- Save ---
signal save_completed(slot: int)
signal load_completed(slot: int)
signal save_feedback(message: String)

# --- Party ---
signal party_member_joined(member_id: StringName)
signal party_member_switched(old_id: StringName, new_id: StringName)
signal party_member_downed(member_id: StringName)
signal party_member_revived(member_id: StringName)
signal team_meter_changed(current: float, maximum: float)

# --- Dialogue ---
signal dialogue_started
signal dialogue_ended

# --- World ---
signal zone_entered(zone_id: StringName)
signal zone_exiting(zone_id: StringName)
signal interaction_available(interactable: Node3D)
signal interaction_cleared

# --- Carry / Throw ---
signal carry_started(obj: Node3D)
signal carry_ended(obj: Node3D, reason: StringName)  # reason: put_down, thrown, hit, forced
signal carryable_in_range(obj: Node3D)

# --- Battle System v3 ---
signal battle_mode_changed(in_battle: bool)
signal combo_step(step: int, kind: StringName)  # kind: &"light" / &"heavy"
signal combo_finisher(kind: StringName, radius: float)
signal stance_changed(member_id: StringName, stance: StringName)
signal enemy_staggered(enemy: Node3D)
# --- Battle v4 (manual toggle, minimap) ---
## Emitted when the player toggles Battle Mode by hand (View button / F).
signal battle_mode_manual_toggled(in_battle: bool)
## Like enemy_damaged, plus who dealt it (the node passed to take_damage: the
## player hitbox owner, a projectile, a thrown crate, a companion...). May be null.
signal enemy_hit(enemy: Node3D, amount: float, source: Node3D)
# --- v5 ---
## Target step: whether the highlighted target is within the selected ability's
## range. (null, true) = reset. Reticle and target bar dim when out of range.
signal tactical_target_reach(target: Node3D, in_range: bool)

# --- UI ---
signal ui_menu_opened(menu_name: StringName)
signal ui_menu_closed(menu_name: StringName)
