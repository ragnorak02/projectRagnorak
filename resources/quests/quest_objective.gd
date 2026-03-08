## Single quest objective (sub-resource of QuestData).
extends Resource

@export var objective_id: StringName = &""
@export var description: String = ""
@export var target_id: StringName = &""
@export var target_count: int = 1
@export var marker_position: Vector3 = Vector3.ZERO
