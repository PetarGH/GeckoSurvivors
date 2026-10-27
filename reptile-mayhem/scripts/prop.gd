class_name Prop
extends Node3D
## Represents a decorative or functional habitat prop placed inside a [Terrarium].

@export var item_name: String = ""
@export var biome: HabitatEnums.BiomeType = HabitatEnums.BiomeType.MEDITERRANEAN
@export var cost: int = 0
@export var score_multiplier_delta: float = 0.1
