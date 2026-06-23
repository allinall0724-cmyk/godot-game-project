extends Node
class_name CharacterPresets
## Starter appearance presets shown on the character-select screen at launch.
##
## Each entry is a plain dictionary consumed by Humanoid.apply_appearance()
## (skin/hair/outfit colors + hair_style + body_type), plus a "name" and short
## "blurb" for the menu card. body_type: 0 = broad build, 1 = feminine build.
## hair_style: 0 short, 1 long, 2 spiky, 3 none.
##
## To add a character: append a dict here — the select screen lists them all
## automatically, no UI wiring needed.

const PRESETS := [
	{
		"name": "Rowan",
		"blurb": "Village squire",
		"body_type": 0,
		"hair_style": 0,
		"skin_color": Color(0.92, 0.76, 0.62),
		"hair_color": Color(0.30, 0.18, 0.06),
		"tunic_color": Color(0.27, 0.36, 0.52),
		"shorts_color": Color(0.20, 0.22, 0.32),
		"legs_color": Color(0.55, 0.56, 0.60),
		"boot_color": Color(0.30, 0.20, 0.10),
	},
	{
		"name": "Bram",
		"blurb": "Hill wanderer",
		"body_type": 0,
		"hair_style": 2,
		"skin_color": Color(0.55, 0.40, 0.30),
		"hair_color": Color(0.08, 0.07, 0.07),
		"tunic_color": Color(0.26, 0.40, 0.28),
		"shorts_color": Color(0.22, 0.18, 0.12),
		"legs_color": Color(0.34, 0.30, 0.24),
		"boot_color": Color(0.22, 0.15, 0.09),
	},
	{
		"name": "Elara",
		"blurb": "Hedge witch",
		"body_type": 1,
		"hair_style": 1,
		"skin_color": Color(0.94, 0.80, 0.68),
		"hair_color": Color(0.52, 0.24, 0.10),
		"tunic_color": Color(0.20, 0.46, 0.45),
		"shorts_color": Color(0.16, 0.30, 0.32),
		"legs_color": Color(0.60, 0.58, 0.56),
		"boot_color": Color(0.28, 0.18, 0.12),
	},
	{
		"name": "Mira",
		"blurb": "Moon acolyte",
		"body_type": 1,
		"hair_style": 1,
		"skin_color": Color(0.48, 0.33, 0.24),
		"hair_color": Color(0.06, 0.05, 0.07),
		"tunic_color": Color(0.34, 0.22, 0.48),
		"shorts_color": Color(0.22, 0.16, 0.32),
		"legs_color": Color(0.40, 0.38, 0.46),
		"boot_color": Color(0.18, 0.14, 0.20),
	},
	{
		"name": "Sora",
		"blurb": "Ember dancer",
		"body_type": 1,
		"hair_style": 0,
		"skin_color": Color(0.96, 0.84, 0.70),
		"hair_color": Color(0.86, 0.72, 0.34),
		"tunic_color": Color(0.62, 0.22, 0.18),
		"shorts_color": Color(0.40, 0.16, 0.14),
		"legs_color": Color(0.70, 0.62, 0.52),
		"boot_color": Color(0.32, 0.16, 0.12),
	},
]
