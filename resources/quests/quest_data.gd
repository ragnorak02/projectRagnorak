## Quest definition resource.
extends Resource

enum QuestType { STORY, SIDE, EXPLORATION }

@export var quest_id: StringName = &""
@export var title: String = ""
@export var description: String = ""
@export var quest_type: QuestType = QuestType.SIDE
@export var objectives: Array[Resource] = []
@export var prerequisite_quests: Array[StringName] = []
@export var rewards: Dictionary = {}
