class_name WorldLocations
extends RefCounted
## Named landmarks on the map. This is plain DATA (no nodes) so it can be reused by
## the minimap, quests, fast travel, signposts, etc. `pos` is the world XZ position;
## `kind` drives the minimap marker colour/size (see Minimap._kind_color).
##
## Kept deliberately SPARSE and spread across the 500×500 world so the minimap doesn't
## get crowded — roughly one landmark per region. Add more here and they appear on the
## minimap automatically. The two mountains are at world (-120,-92) and (120,100); the
## home village clearing is at the origin.

const ALL := [
	{"name": "Hearthwick Village", "kind": "village", "pos": Vector2(-12, -12)},
	{"name": "Whisperwood", "kind": "forest", "pos": Vector2(185, 30)},
	{"name": "Aldermarket City", "kind": "city", "pos": Vector2(160, -150)},
	{"name": "Ironwatch Fortress", "kind": "fortress", "pos": Vector2(-30, -200)},
	{"name": "Highrock Castle", "kind": "castle", "pos": Vector2(-200, -20)},
	{"name": "Sunspire, the Capital", "kind": "kingdom", "pos": Vector2(-150, 160)},
	{"name": "The Bonefields", "kind": "undead", "pos": Vector2(-40, 200)},
	# At the southern foot of the eastern mountain — the peak rises behind the lair.
	{"name": "Dragon's Maw", "kind": "dragon", "pos": Vector2(120, 195)},
]
