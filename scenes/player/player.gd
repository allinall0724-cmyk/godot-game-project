extends CharacterBody3D
## Third-person player pawn.
##
## Controls:
##   - WASD: camera-relative movement
##   - Mouse: look (handled by the camera rig)
##   - Space: jump (only when grounded)
##   - Left click: melee attack (Area3D hitbox briefly enabled in front)
##   - E: board/exit a nearby ship (handled by Main)
##
## The camera is NOT a child of the player anymore; it lives in Main and follows
## us via set_target(). We get a reference to it (set_camera) so movement can be
## camera-relative and so we can face where the camera looks.

# --- Movement / jump tuning (BASE values; equipped items modify them) ---
const BASE_MOVE_SPEED := 5.0
const ACCELERATION := 15.0
const FRICTION := 10.0
# A snappy, game-feel jump (not floaty): with GRAVITY 22, JUMP_VELOCITY 7.5 peaks
# at ~1.28 m — clears the capsule cleanly and comes back down quickly.
const GRAVITY := 22.0
const BASE_JUMP_VELOCITY := 7.5

# --- Attack tuning (the STAFF is the basic-attack weapon) ---
# The player always wields a single staff. Melee damage scales with its tier (see
# get_attack_damage()); the directional/charge/dodge melee mechanics are unchanged.
const BASE_ATTACK_DAMAGE := 2   # Tier 1 baseline; +2 per tier above 1
const ATTACK_DURATION := 0.18   # how long the hitbox stays active per swing
const ATTACK_COOLDOWN := 0.40   # base min time between swings
const STAFF_REACH := 1.15       # melee hitbox scale (the staff is long)
const MAX_CHARGE := 1.0         # seconds to fully charge an attack
const CHARGE_DMG_BONUS := 1.5   # +150% damage at full charge

# --- Spells (equipped on the staff) ---
# The player slots up to MAX_SPELLS spells onto the staff. Each spell is a DISTINCT
# ability (not a scaled repeat). Slots map to keys Q/R/F/C/V (ability_1..ability_5)
# and each has its OWN cooldown. This is the former "element/ability" system,
# reframed: the spell catalog below is keyed by id; `equipped_spells` chooses which
# 5 are bound. (Leveling / unlock-progression that gates the catalog is a future
# prompt — for now the default loadout is simply filled in.)
const FIREBALL_SCENE := "res://scenes/abilities/fireball.tscn"
const METEOR_SCENE := "res://scenes/abilities/meteor.tscn"
const LIGHTNING_RANGE := 9.0
const MAX_SPELLS := 5

const FIRE_COL := Color(1.0, 0.5, 0.12)
const LTNG_COL := Color(0.6, 0.82, 1.0)
const WIND_COL := Color(0.6, 1.0, 0.72)
const SKY_COL := Color(0.85, 0.92, 1.0)
const ICE_COL := Color(0.62, 0.86, 1.0)
const EARTH_COL := Color(0.62, 0.46, 0.28)
const ARCANE_COL := Color(0.78, 0.55, 1.0)
const SHADOW_COL := Color(0.55, 0.3, 0.7)
const NATURE_COL := Color(0.45, 0.8, 0.35)
const MINION_SCENE := "res://scenes/abilities/minion.tscn"
const DECOY_SCENE := "res://scenes/abilities/decoy.tscn"

# Spell catalog. Each has: "name", "effect", "cost" (stamina), "cd" (cooldown s),
# "element" (theme/tint), plus effect-specific params, and optional "windup"
# (telegraph delay before the effect — skilled players time it).
const SPELLS := {
	# Fire
	"fireball":      {"name": "Fireball", "effect": "projectile", "cost": 12, "cd": 0.5, "count": 1, "size": 1.0, "speed": 20.0, "dmg": 2, "element": "fire", "color": FIRE_COL},
	"fire_cone":     {"name": "Fire Cone", "effect": "cone", "cost": 16, "cd": 0.9, "range": 4.5, "angle": 45.0, "dmg": 3, "element": "fire", "color": FIRE_COL},
	"ring_of_fire":  {"name": "Ring of Fire", "effect": "nova", "cost": 22, "cd": 1.2, "radius": 3.5, "dmg": 3, "element": "fire", "color": FIRE_COL},
	"flame_dash":    {"name": "Flame Dash", "effect": "dash", "cost": 18, "cd": 0.9, "speed": 26.0, "trail": true, "dmg": 2, "element": "fire", "color": FIRE_COL},
	"meteor":        {"name": "Meteor", "effect": "meteor", "cost": 30, "cd": 2.0, "windup": 0.6, "size": 2.0, "dmg": 9, "radius": 3.2, "element": "fire", "color": FIRE_COL},
	"comet":         {"name": "Comet", "effect": "projectile", "cost": 18, "cd": 0.8, "count": 1, "size": 0.8, "speed": 40.0, "dmg": 6, "pierce": true, "element": "fire", "color": FIRE_COL},
	# Lightning
	"lightning_zap":   {"name": "Lightning Zap", "effect": "strike", "cost": 14, "cd": 0.6, "targets": 1, "dmg": 3, "element": "lightning", "color": LTNG_COL},
	"chain_lightning": {"name": "Chain Lightning", "effect": "strike", "cost": 18, "cd": 1.0, "targets": 3, "dmg": 2, "element": "lightning", "color": LTNG_COL},
	"lightning_nova":  {"name": "Lightning Nova", "effect": "nova", "cost": 22, "cd": 1.3, "radius": 4.0, "dmg": 3, "element": "lightning", "color": LTNG_COL},
	"blink_strike":    {"name": "Blink Strike", "effect": "dash", "cost": 20, "cd": 1.1, "speed": 34.0, "strike": true, "dmg": 4, "element": "lightning", "color": LTNG_COL},
	"thunderstorm":    {"name": "Thunderstorm", "effect": "storm", "cost": 32, "cd": 2.2, "windup": 0.5, "count": 6, "spread": 6.0, "dmg": 3, "element": "lightning", "color": LTNG_COL},
	"thunder_spear":   {"name": "Thunder Spear", "effect": "strike", "cost": 24, "cd": 1.4, "targets": 1, "dmg": 8, "element": "lightning", "color": LTNG_COL},
	# Wind
	"dodge_roll":    {"name": "Dodge Roll", "effect": "dash", "cost": 14, "cd": 0.9, "speed": 24.0, "element": "wind", "color": WIND_COL},
	"gust":          {"name": "Gust", "effect": "knockback", "cost": 16, "cd": 0.8, "range": 5.0, "force": 14.0, "dmg": 1, "element": "wind", "color": WIND_COL},
	"wind_slash":    {"name": "Wind Slash", "effect": "projectile", "cost": 16, "cd": 0.5, "count": 1, "size": 1.2, "speed": 32.0, "dmg": 3, "element": "wind", "color": WIND_COL},
	"updraft":       {"name": "Updraft", "effect": "vertical", "cost": 16, "cd": 1.0, "power": 12.0, "element": "wind", "color": WIND_COL},
	"cyclone":       {"name": "Cyclone", "effect": "knockback", "cost": 24, "cd": 1.4, "range": 4.0, "force": 18.0, "dmg": 2, "radial": true, "element": "wind", "color": WIND_COL},
	"cyclone_throw": {"name": "Cyclone Throw", "effect": "projectile", "cost": 18, "cd": 0.6, "count": 1, "size": 1.1, "speed": 36.0, "dmg": 5, "element": "wind", "color": WIND_COL},
	# Sky
	"levitate":      {"name": "Levitate", "effect": "fly", "cost": 6, "cd": 0.5, "element": "sky", "color": SKY_COL},
	"air_dash":      {"name": "Air Dash", "effect": "dash", "cost": 16, "cd": 0.7, "speed": 24.0, "element": "sky", "color": SKY_COL},
	"sky_updraft":   {"name": "Sky Updraft", "effect": "vertical", "cost": 14, "cd": 0.9, "power": 13.0, "element": "sky", "color": SKY_COL},
	"glide":         {"name": "Glide", "effect": "glide", "cost": 10, "cd": 1.5, "element": "sky", "color": SKY_COL},
	"ground_pound":  {"name": "Ground Pound", "effect": "pound", "cost": 22, "cd": 1.2, "radius": 4.0, "dmg": 6, "element": "sky", "color": SKY_COL},
	"dive_bomb":     {"name": "Dive Bomb", "effect": "pound", "cost": 26, "cd": 1.5, "radius": 5.5, "dmg": 9, "element": "sky", "color": SKY_COL},

	# --- Ice (slows / control) ---
	"frost_bolt":    {"name": "Frost Bolt", "effect": "projectile", "cost": 14, "cd": 0.6, "count": 1, "size": 1.0, "speed": 22.0, "dmg": 3, "slow": 0.5, "slow_dur": 3.0, "element": "ice", "color": ICE_COL},
	"frost_nova":    {"name": "Frost Nova", "effect": "frost_nova", "cost": 22, "cd": 1.6, "radius": 4.0, "dmg": 3, "slow": 0.45, "slow_dur": 3.0, "element": "ice", "color": ICE_COL},
	"frost_bind":    {"name": "Frost Bind", "effect": "debuff", "cost": 18, "cd": 2.0, "status": "root", "radius": 5.0, "duration": 2.0, "element": "ice", "color": ICE_COL},
	"ice_shards":    {"name": "Ice Shards", "effect": "shotgun", "cost": 22, "cd": 1.0, "pellets": 8, "spread": 0.5, "speed": 30.0, "size": 0.6, "dmg": 2, "slow": 0.6, "slow_dur": 2.0, "element": "ice", "color": ICE_COL},
	"ice_wall":      {"name": "Ice Wall", "effect": "structure", "cost": 18, "cd": 3.0, "structure": "wall", "size": Vector3(5.0, 2.6, 0.5), "life": 8.0, "element": "ice", "color": ICE_COL},
	"blizzard":      {"name": "Blizzard", "effect": "blizzard", "cost": 40, "cd": 6.0, "windup": 0.4, "radius": 6.0, "ticks": 6, "dmg": 2, "slow": 0.5, "slow_dur": 1.5, "element": "ice", "color": ICE_COL},

	# --- Earth (heavy hits / structures) ---
	"boulder_toss":  {"name": "Boulder Toss", "effect": "projectile", "cost": 20, "cd": 1.0, "count": 1, "size": 1.6, "speed": 15.0, "dmg": 6, "knock": 12.0, "gravity": 16.0, "arc": true, "element": "earth", "color": EARTH_COL},
	"stone_spikes":  {"name": "Stone Spikes", "effect": "spikes", "cost": 20, "cd": 1.2, "range": 8.0, "width": 2.0, "dmg": 5, "element": "earth", "color": EARTH_COL},
	"quagmire":      {"name": "Quagmire", "effect": "debuff", "cost": 16, "cd": 1.5, "status": "slow", "factor": 0.4, "radius": 5.0, "duration": 4.0, "element": "earth", "color": EARTH_COL},
	"stone_wall":    {"name": "Stone Wall", "effect": "structure", "cost": 20, "cd": 3.0, "structure": "wall", "size": Vector3(3.5, 2.4, 1.0), "life": 10.0, "element": "earth", "color": EARTH_COL},
	"earthen_ramp":  {"name": "Earthen Ramp", "effect": "structure", "cost": 16, "cd": 3.0, "structure": "ramp", "size": Vector3(3.0, 0.5, 5.0), "life": 12.0, "element": "earth", "color": EARTH_COL},
	"earthquake":    {"name": "Earthquake", "effect": "quake", "cost": 45, "cd": 6.0, "windup": 0.5, "radius": 8.0, "dmg": 8, "force": 14.0, "element": "earth", "color": EARTH_COL},

	# --- Gun-style (magic ranged archetypes) ---
	"arc_sniper":    {"name": "Arc Sniper", "effect": "beam", "cost": 26, "cd": 2.0, "windup": 0.35, "zoom": true, "range": 60.0, "dmg": 16, "element": "lightning", "color": LTNG_COL},
	"ember_burst":   {"name": "Ember Burst", "effect": "shotgun", "cost": 22, "cd": 1.0, "pellets": 8, "spread": 0.55, "speed": 28.0, "size": 0.7, "dmg": 3, "element": "fire", "color": FIRE_COL},
	"spark_repeater":{"name": "Spark Repeater", "effect": "rapid", "cost": 20, "cd": 1.2, "shots": 6, "interval": 0.08, "speed": 38.0, "size": 0.5, "dmg": 2, "element": "lightning", "color": LTNG_COL},

	# --- Mobility ---
	"blink":         {"name": "Blink", "effect": "teleport", "cost": 14, "cd": 1.0, "range": 12.0, "element": "arcane", "color": ARCANE_COL},

	# --- Structure (utility) ---
	"sky_platform":  {"name": "Sky Platform", "effect": "structure", "cost": 16, "cd": 3.0, "structure": "platform", "size": Vector3(3.0, 0.4, 3.0), "life": 8.0, "element": "sky", "color": SKY_COL},

	# --- Self buffs (timed) ---
	"empower":       {"name": "Empower", "effect": "buff", "cost": 20, "cd": 8.0, "buff": "power", "amount": 0.5, "duration": 20.0, "element": "fire", "color": FIRE_COL},
	"haste":         {"name": "Haste", "effect": "buff", "cost": 16, "cd": 8.0, "buff": "speed", "amount": 3.5, "duration": 12.0, "element": "wind", "color": WIND_COL},
	"stone_skin":    {"name": "Stone Skin", "effect": "buff", "cost": 18, "cd": 10.0, "buff": "shield", "amount": 0.5, "duration": 12.0, "element": "earth", "color": EARTH_COL},
	"arcane_focus":  {"name": "Arcane Focus", "effect": "buff", "cost": 8, "cd": 8.0, "buff": "regen", "amount": 30.0, "duration": 10.0, "element": "arcane", "color": ARCANE_COL},
	"second_wind":   {"name": "Second Wind", "effect": "buff", "cost": 0, "cd": 16.0, "buff": "restore", "amount": 60.0, "duration": 0.0, "element": "wind", "color": WIND_COL},

	# --- Utility ---
	"blinding_flash":{"name": "Blinding Flash", "effect": "debuff", "cost": 16, "cd": 1.6, "status": "fear", "radius": 6.0, "duration": 2.5, "element": "lightning", "color": LTNG_COL},

	# --- Ultimate ---
	"meteor_shower": {"name": "Meteor Shower", "effect": "shower", "cost": 50, "cd": 7.0, "windup": 0.8, "count": 7, "spread": 7.0, "dmg": 8, "radius": 3.0, "size": 1.6, "element": "fire", "color": FIRE_COL},

	# === Pass 3 ===
	# Summons
	"fire_elemental": {"name": "Summon Fire Elemental", "effect": "summon", "cost": 30, "cd": 8.0, "kind": "fire", "dmg": 2, "life": 12.0, "element": "fire", "color": FIRE_COL},
	"stone_golem":    {"name": "Summon Stone Golem", "effect": "summon", "cost": 34, "cd": 10.0, "kind": "golem", "dmg": 3, "life": 15.0, "element": "earth", "color": EARTH_COL},
	# Terrain-altering zones
	"frozen_ground":  {"name": "Frozen Ground", "effect": "zone", "cost": 20, "cd": 4.0, "radius": 4.5, "life": 8.0, "slow": 0.4, "slow_dur": 1.0, "element": "ice", "color": ICE_COL},
	"mire":           {"name": "Mire", "effect": "zone", "cost": 18, "cd": 4.0, "radius": 4.0, "life": 8.0, "slow": 0.3, "slow_dur": 1.0, "element": "earth", "color": Color(0.4, 0.32, 0.2)},
	"scorched_earth": {"name": "Scorched Earth", "effect": "zone", "cost": 22, "cd": 4.0, "radius": 4.0, "life": 6.0, "dot": 4.0, "element": "fire", "color": FIRE_COL},
	# Area denial
	"poison_cloud":   {"name": "Poison Cloud", "effect": "zone", "cost": 24, "cd": 5.0, "radius": 4.5, "life": 8.0, "dot": 5.0, "slow": 0.7, "slow_dur": 1.0, "height": 1.2, "element": "nature", "color": NATURE_COL},
	"thorn_patch":    {"name": "Thorn Patch", "effect": "zone", "cost": 20, "cd": 4.0, "radius": 4.0, "life": 8.0, "dmg": 2, "slow": 0.6, "slow_dur": 1.0, "element": "nature", "color": Color(0.3, 0.55, 0.25)},
	# Environmental: spreading wildfire
	"wildfire":       {"name": "Wildfire", "effect": "zone", "cost": 26, "cd": 5.0, "radius": 2.5, "life": 7.0, "dot": 5.0, "grow": 0.5, "element": "fire", "color": Color(1.0, 0.4, 0.1)},
	# Drain / lifesteal
	"life_siphon":    {"name": "Life Siphon", "effect": "drain", "cost": 16, "cd": 1.5, "dmg": 6, "ratio": 0.6, "mode": "health", "element": "shadow", "color": SHADOW_COL},
	"mana_leech":     {"name": "Mana Leech", "effect": "drain", "cost": 6, "cd": 1.5, "dmg": 3, "gain": 16.0, "mode": "stamina", "element": "arcane", "color": ARCANE_COL},
	# Curse / DoT
	"curse_of_embers":{"name": "Curse of Embers", "effect": "curse", "cost": 20, "cd": 2.5, "radius": 4.0, "dps": 4.0, "duration": 5.0, "element": "fire", "color": FIRE_COL},
	"withering_hex":  {"name": "Withering Hex", "effect": "curse", "cost": 18, "cd": 3.0, "radius": 3.0, "dps": 5.0, "duration": 4.0, "slow": 0.6, "element": "shadow", "color": SHADOW_COL},
	# Reflect / counter
	"counter_ward":   {"name": "Counter Ward", "effect": "reflect", "cost": 18, "cd": 5.0, "duration": 2.5, "dmg": 7, "element": "arcane", "color": ARCANE_COL},
	# Clone / decoy
	"mirror_image":   {"name": "Mirror Image", "effect": "decoy", "cost": 20, "cd": 6.0, "life": 8.0, "element": "arcane", "color": ARCANE_COL},
	# Chain / bounce
	"arc_chain":      {"name": "Arc Chain", "effect": "chain", "cost": 22, "cd": 1.4, "jumps": 5, "range": 7.0, "dmg": 4, "element": "lightning", "color": LTNG_COL},
	# Stealth
	"veil":           {"name": "Veil", "effect": "stealth", "cost": 16, "cd": 8.0, "duration": 5.0, "element": "shadow", "color": SHADOW_COL},
	# Detection / scouting
	"farsight":       {"name": "Farsight", "effect": "reveal", "cost": 8, "cd": 4.0, "radius": 35.0, "duration": 6.0, "element": "arcane", "color": ARCANE_COL},

	# === Pass 4 — gravity arcs, deployables, channels, homing ===
	"fire_bomb":      {"name": "Fire Bomb", "effect": "projectile", "cost": 24, "cd": 1.4, "count": 1, "size": 1.2, "speed": 16.0, "dmg": 6, "gravity": 18.0, "arc": true, "explode_radius": 3.2, "element": "fire", "color": FIRE_COL},
	"frost_grenade":  {"name": "Frost Grenade", "effect": "projectile", "cost": 22, "cd": 1.4, "count": 1, "size": 1.0, "speed": 16.0, "dmg": 3, "gravity": 18.0, "arc": true, "explode_radius": 3.4, "slow": 0.4, "slow_dur": 3.0, "element": "ice", "color": ICE_COL},
	"ice_lance":      {"name": "Ice Lance", "effect": "projectile", "cost": 18, "cd": 0.9, "count": 1, "size": 0.8, "speed": 42.0, "dmg": 4, "pierce": true, "slow": 0.6, "slow_dur": 2.5, "element": "ice", "color": ICE_COL},
	"spirit_wisps":   {"name": "Spirit Wisps", "effect": "projectile", "cost": 22, "cd": 1.2, "count": 3, "size": 0.6, "speed": 18.0, "dmg": 3, "homing": 6.0, "element": "arcane", "color": ARCANE_COL},
	"singularity":    {"name": "Singularity", "effect": "pull", "cost": 36, "cd": 6.0, "windup": 0.3, "radius": 7.0, "force": 9.0, "ticks": 8, "dmg": 2, "element": "arcane", "color": ARCANE_COL},
	"storm_totem":    {"name": "Storm Totem", "effect": "totem", "cost": 28, "cd": 6.0, "life": 8.0, "range": 9.0, "dmg": 3, "interval": 0.8, "element": "lightning", "color": LTNG_COL},
	"sanctuary":      {"name": "Sanctuary", "effect": "heal_zone", "cost": 20, "cd": 8.0, "radius": 4.0, "life": 8.0, "heal": 4, "element": "nature", "color": NATURE_COL},
	"tempest":        {"name": "Tempest", "effect": "channel", "cost": 26, "cd": 3.0, "radius": 4.5, "ticks": 8, "dmg": 2, "force": 6.0, "element": "wind", "color": WIND_COL},
	"cinder_aura":    {"name": "Cinder Aura", "effect": "aura", "cost": 22, "cd": 8.0, "duration": 8.0, "radius": 3.5, "dot": 3.0, "element": "fire", "color": FIRE_COL},
	"chain_frost":    {"name": "Chain Frost", "effect": "chain", "cost": 22, "cd": 1.6, "jumps": 5, "range": 7.0, "dmg": 3, "slow": 0.5, "slow_dur": 2.5, "element": "ice", "color": ICE_COL},
}

# Until leveling exists, start with a varied 5-spell loadout (bound to Q/R/F/C/V).
# Slot 3 (F) is Levitate so the flight spell is testable out of the gate.
const DEFAULT_SPELLS := ["fireball", "lightning_zap", "levitate", "gust", "meteor"]

# --- Flight (Levitate spell) ---
const FLY_SPEED := 10.0      # flight movement speed
const FLY_VERTICAL := 7.0    # ascend/descend speed (jump = up, sprint = down)
const FLY_DRAIN := 16.0      # stamina/sec while airborne under flight
const GROUND_SNAP := 0.6     # floor_snap_length on foot (matches player.tscn); 0 while flying

@onready var attack_hitbox: Area3D = $AttackHitbox
@onready var attack_shape: CollisionShape3D = $AttackHitbox/CollisionShape3D
@onready var humanoid = $Humanoid  # visual body; provides the hand attach point

var camera = null                  # the shared camera rig (for camera-relative move)
var active := true                 # false while sailing (Main disables control)

var _attack_timer := 0.0           # remaining active time of the current swing
var _attack_cooldown := 0.0        # remaining cooldown
var _already_hit: Array = []       # enemies already damaged by the current swing
var _charging := false             # holding attack to charge
var _charge_time := 0.0            # how long the current swing was charged
var _attack_dir := "stab"          # "up" / "down" / "stab"

# Spells currently slotted onto the staff (ids into SPELLS), bound to Q/R/F/C/V.
var equipped_spells: Array = DEFAULT_SPELLS.duplicate()
var _spell_cd := [0.0, 0.0, 0.0, 0.0, 0.0]  # per-slot cooldowns
var _book_index := -1                       # G-cycle position into the spellbook
var _glide_time := 0.0             # remaining glide (reduced gravity) time
var _flying := false               # Levitate flight mode active
var _pounding := false             # ground-pound in progress

# Timed self-buffs (from buff spells). Times in seconds remaining.
var _power_time := 0.0             # +damage
var _power_amt := 0.0              # fractional bonus (0.5 = +50%)
var _speed_time := 0.0             # +move speed
var _speed_amt := 0.0              # flat bonus
var _shield_time := 0.0            # damage reduction
var _shield_amt := 0.0             # fraction reduced (0.5 = -50% taken)
var _regen_buff_time := 0.0        # +stamina regen
var _regen_buff_amt := 0.0
var _counter_time := 0.0           # Counter Ward active window
var _counter_dmg := 0              # damage reflected to melee attackers
var _stealth_time := 0.0           # Veil (enemies can't see us)
var _aura_time := 0.0              # Cinder Aura: damages nearby enemies over time
var _aura_radius := 0.0
var _aura_dot := 0.0
var _aura_color := Color(1, 0.5, 0.15)
var _aura_tick := 0.0
var _pound_params := {}            # params for the pending pound AoE
var _meteor_target := Vector3.ZERO # landing point fixed at cast (telegraph + impact)

# Dash trail (Flame Dash): damages enemies along the path and leaves flames.
var _trail_time := 0.0
var _trail_color := Color(1, 0.5, 0.1)
var _trail_dmg := 0
var _trail_hit: Array = []

# --- Inventory (very basic) ---
# Items are simple dictionaries. The "rarity"/"tier"/"edition" fields mirror the
# loot model in GAME_DESIGN.md 1.6/1.7 so this slots into that system later.
# The player always wields a staff (the basic-attack weapon). Spells are equipped
# separately (see equipped_spells), not tied to the staff item.
const STARTING_STAFF := {
	"name": "Apprentice Staff",
	"rarity": "Common",
	"tier": 1,
	"edition": 1,
	"slot": "weapon",
	"element": "",  # the staff itself has no element; spells carry the elements
	"scene": "res://scenes/items/staff.tscn",
	"color": Color(0.5, 0.75, 1.0),
}

var inventory: Array = []          # everything the player is carrying
var equipped_weapon: Node3D = null # the currently-held weapon instance (in the hand)

# Distinct equipment slots. Only "weapon" is functional for now; the others exist
# as structure for future armor items (helmet/chest/legs).
var equipment := {
	"helmet": null,
	"chest": null,
	"legs": null,
	"weapon": null,
}

# --- Health ---
var max_health := 100
var health := 100

# --- Stamina / sprint ---
const SPRINT_MULT := 1.6           # move-speed multiplier while sprinting
const SPRINT_DRAIN := 24.0         # stamina/sec while sprinting
const STAMINA_REGEN := 20.0        # stamina/sec when idle
const REGEN_DELAY := 0.5           # pause before regen after spending
var max_stamina := 100.0
var stamina := 100.0
var _regen_delay := 0.0
var is_sprinting := false

# Shared low-poly mesh reused by every VFX particle (avoids per-spawn mesh upload
# stutter). Created once in _ready.
var _fx_sphere: SphereMesh


func _ready() -> void:
	# Tagged so the multiplayer avatar can mirror our transform to other players.
	add_to_group("local_player")
	attack_shape.disabled = true

	_fx_sphere = SphereMesh.new()
	_fx_sphere.radius = 1.0
	_fx_sphere.height = 2.0
	_fx_sphere.radial_segments = 8
	_fx_sphere.rings = 4

	# Give the player their staff and equip it (visible in hand).
	add_item(STARTING_STAFF)
	equip(STARTING_STAFF)


func set_camera(c: Node3D) -> void:
	camera = c


## Called by Main when boarding/leaving the ship. Disabling physics freezes us
## in place (Main hides us and rides us along with the ship).
func set_active(value: bool) -> void:
	active = value
	set_physics_process(value)


func _physics_process(delta: float) -> void:
	_update_attack(delta)
	_update_cooldowns(delta)
	_update_buffs(delta)

	# Safety net: if we ever fall through/off the world, respawn above the village.
	if active and global_position.y < -25.0:
		global_position = Vector3(0.0, 4.0, 0.0)
		velocity = Vector3.ZERO

	if active:
		_update_melee(delta)
		_handle_abilities()
		# Testing aid: G rotates the V slot (slot 5) through the WHOLE spellbook so
		# every spell is reachable without a loadout UI (still only 5 equipped).
		if Input.is_action_just_pressed("ability_6"):
			_cycle_spellbook_slot()
		_update_trail(delta)

	if active and _flying:
		# Levitate: free 3D flight, gravity off, costs stamina (see _update_flight).
		_update_flight(delta)
	else:
		# Gravity (reduced while gliding).
		if not is_on_floor():
			var g := GRAVITY
			if _glide_time > 0.0:
				g *= 0.25
				_glide_time -= delta
				# Airy glide wisps.
				if int(_glide_time * 30.0) % 4 == 0:
					_spawn_emitter(global_position + Vector3.UP * 0.5, Color(0.82, 0.92, 1.0), 0.1, 0.35, Vector3.DOWN * 0.4)
			velocity.y -= g * delta
		else:
			_glide_time = 0.0
			if _pounding:
				_pounding = false
				_resolve_pound()

		# Ground jump (mobility spells like Updraft / dashes cover the air game).
		if active and Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = get_jump_velocity()

		# Horizontal, camera-relative movement (same convention already validated on foot)
		var move_dir := _get_movement_input() if active else Vector3.ZERO
		is_sprinting = active and Input.is_action_pressed("sprint") and move_dir.length() > 0.1 and stamina > 0.0
		_update_stamina(delta)
		var desired := move_dir * get_move_speed() * (SPRINT_MULT if is_sprinting else 1.0)
		var horizontal := Vector3(velocity.x, 0.0, velocity.z)
		var desired_h := Vector3(desired.x, 0.0, desired.z)
		if desired_h.length() > 0.01:
			horizontal = horizontal.lerp(desired_h, ACCELERATION * delta)
		else:
			horizontal = horizontal.lerp(Vector3.ZERO, FRICTION * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.z

		move_and_slide()

	# Drive the walk animation from our actual horizontal speed.
	humanoid.move_speed = Vector3(velocity.x, 0.0, velocity.z).length() if active else 0.0

	# Face where the camera is looking so the melee hitbox points "forward".
	if active and camera != null:
		var look: Vector3 = camera.get_forward_direction()
		look.y = 0.0
		if look.length() > 0.01:
			look_at(global_position + look, Vector3.UP)


func _get_movement_input() -> Vector3:
	# Note arg order: get_vector(neg_x, pos_x, neg_y, pos_y). With the camera rig in
	# Main, "forward" must map to +y here, so move_forward is the positive_y action.
	var input_dir := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	# Explicit Vector3 type: camera is untyped (Variant), so := can't infer it.
	var camera_forward: Vector3 = camera.get_forward_direction()
	var camera_right: Vector3 = camera.get_right_direction()
	camera_forward.y = 0
	camera_right.y = 0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	# Negate the strafe term: camera_right points opposite to the A/D expectation,
	# so without this, A moves right and D moves left.
	return (camera_forward * input_dir.y - camera_right * input_dir.x).normalized()


# --- Melee attack (charged + directional + weapon-type feel) ---

## Hold attack to charge; release to swing. Direction comes from a held movement
## key at release: W = upward swipe, S = downward chop, otherwise a forward stab.
func _update_melee(delta: float) -> void:
	if _charging:
		_charge_time = minf(_charge_time + delta, MAX_CHARGE)
		# Charge tell: the weapon swells the longer you hold.
		if equipped_weapon != null:
			equipped_weapon.scale = Vector3.ONE * (1.0 + (_charge_time / MAX_CHARGE) * 0.3)
		if Input.is_action_just_released("attack"):
			_release_attack()
	elif Input.is_action_just_pressed("attack") and _attack_cooldown <= 0.0:
		_charging = true
		_charge_time = 0.0


func _release_attack() -> void:
	_charging = false
	if Input.is_action_pressed("move_forward"):
		_attack_dir = "up"
	elif Input.is_action_pressed("move_back"):
		_attack_dir = "down"
	else:
		_attack_dir = "stab"
	var ratio := _charge_time / MAX_CHARGE
	_attack_cooldown = ATTACK_COOLDOWN * (1.0 + ratio * 0.4)
	_attack_timer = ATTACK_DURATION * (1.0 + ratio * 0.3)
	_already_hit.clear()
	attack_shape.disabled = false
	if equipped_weapon != null:
		equipped_weapon.scale = Vector3.ONE  # reset charge swell
	humanoid.play_attack(_attack_dir, ratio)
	# A charged swing flashes with sparks.
	if ratio > 0.5:
		var fwd := -global_transform.basis.z
		_spawn_burst(global_position + fwd * 1.0 + Vector3.UP * 1.0, 0.7, Color(1.0, 0.92, 0.6), 6)


func _update_attack(delta: float) -> void:
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta

	if _attack_timer > 0.0:
		# Scan everything currently inside the hitbox and damage new targets.
		for body in attack_hitbox.get_overlapping_bodies():
			_try_damage(body)
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			attack_shape.disabled = true


func _try_damage(body: Node) -> void:
	if body == self or body in _already_hit:
		return
	if body.has_method("take_damage"):
		_already_hit.append(body)
		body.take_damage(_compute_melee_damage())
		if body.has_method("apply_knockback"):
			body.apply_knockback(_melee_knockback())


## Staff damage × charge bonus × direction multiplier.
func _compute_melee_damage() -> int:
	var ratio := _charge_time / MAX_CHARGE
	var dir_mult := 1.0
	if _attack_dir == "down":
		dir_mult = 1.3
	elif _attack_dir == "up":
		dir_mult = 0.9
	var dmg := float(get_attack_damage()) * (1.0 + ratio * CHARGE_DMG_BONUS) * dir_mult
	return _amp(maxi(1, int(round(dmg))))


## Knockback vector depends on swing direction (and charge power).
func _melee_knockback() -> Vector3:
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var power := 6.0 + (_charge_time / MAX_CHARGE) * 6.0
	if _attack_dir == "up":
		return fwd * (power * 0.4) + Vector3.UP * (7.0 + (_charge_time / MAX_CHARGE) * 4.0)
	elif _attack_dir == "down":
		return fwd * (power * 1.4) + Vector3.DOWN * 2.0
	return fwd * (power * 1.2)


# --- Stats (real values, modified by equipped items) ---

## Tier of the currently equipped weapon (0 if unarmed). Used for melee damage.
func weapon_tier() -> int:
	var w = equipment.get("weapon")
	return int(w.get("tier", 1)) if w != null else 0


## The currently-slotted spells for the ability bar UI. Slot order is the key order
## Q/R/F/C/V (ability_1..ability_5).
func get_ability_bar_moves() -> Array:
	var keys := ["Q", "R", "F", "C", "V"]
	var out: Array = []
	for i in range(mini(MAX_SPELLS, equipped_spells.size())):
		var spell: Dictionary = SPELLS.get(equipped_spells[i], {})
		if spell.is_empty():
			continue
		out.append({
			"name": str(spell.get("name", "?")),
			"key": keys[i],
			"cost": int(spell.get("cost", 0)),
			"element": str(spell.get("element", "")),
		})
	return out


## Melee damage scales with weapon tier: Tier 1 = 2, +2 per tier (unarmed = 1).
func get_attack_damage() -> int:
	var t := weapon_tier()
	if t <= 0:
		return 1
	return BASE_ATTACK_DAMAGE + (t - 1) * 2


## Move speed = base + equipped items' "move_mod" / "speed_bonus".
func get_move_speed() -> float:
	var s := BASE_MOVE_SPEED
	for slot in equipment:
		var it = equipment[slot]
		if it != null:
			s += float(it.get("move_mod", 0.0)) + float(it.get("speed_bonus", 0.0))
	if _speed_time > 0.0:
		s += _speed_amt  # Haste buff
	return maxf(2.0, s)


## Passive: max health = 100 + equipped items' "health_bonus".
func get_max_health() -> int:
	var h := 100
	for slot in equipment:
		var it = equipment[slot]
		if it != null:
			h += int(it.get("health_bonus", 0))
	return h


## Passive: stamina regen = base + equipped items' "regen_bonus".
func get_stamina_regen() -> float:
	var r := STAMINA_REGEN
	for slot in equipment:
		var it = equipment[slot]
		if it != null:
			r += float(it.get("regen_bonus", 0.0))
	if _regen_buff_time > 0.0:
		r += _regen_buff_amt  # Arcane Focus buff
	return r


## Jump take-off velocity = base + sum of equipped items' "jump_mod".
func get_jump_velocity() -> float:
	var j := BASE_JUMP_VELOCITY
	for slot in equipment:
		var it = equipment[slot]
		if it != null:
			j += float(it.get("jump_mod", 0.0))
	return maxf(4.0, j)


## Resulting peak jump height (for display).
func get_jump_height() -> float:
	var v := get_jump_velocity()
	return v * v / (2.0 * GRAVITY)


# --- Abilities ---

func _update_cooldowns(delta: float) -> void:
	for i in range(_spell_cd.size()):
		if _spell_cd[i] > 0.0:
			_spell_cd[i] -= delta


## Count down the timed self-buffs.
func _update_buffs(delta: float) -> void:
	if _power_time > 0.0:
		_power_time -= delta
	if _speed_time > 0.0:
		_speed_time -= delta
	if _shield_time > 0.0:
		_shield_time -= delta
	if _regen_buff_time > 0.0:
		_regen_buff_time -= delta
	if _counter_time > 0.0:
		_counter_time -= delta
	if _stealth_time > 0.0:
		_stealth_time -= delta
		# Faint shimmer while hidden.
		if Engine.get_physics_frames() % 10 == 0:
			_spawn_emitter(global_position + Vector3.UP * 1.0, SHADOW_COL, 0.1, 0.4, Vector3.UP * 0.4)
	if _aura_time > 0.0:
		_aura_time -= delta
		_aura_tick -= delta
		if _aura_tick <= 0.0:
			_aura_tick = 0.5
			for e in get_tree().get_nodes_in_group("enemies"):
				if global_position.distance_to(e.global_position) <= _aura_radius and e.has_method("apply_dot"):
					e.apply_dot(_aura_dot, 0.8)
			for i in range(5):
				var a := TAU * float(i) / 5.0
				_spawn_emitter(global_position + Vector3(cos(a) * _aura_radius * 0.8, 0.3, sin(a) * _aura_radius * 0.8), _aura_color, 0.12, 0.4, Vector3.UP * 0.5)


## Called by enemies' attacks: true while Counter Ward is active (they get reflected).
func is_countering() -> bool:
	return _counter_time > 0.0


## Called by enemies' attacks: true while Veil is active (they can't see us).
func is_stealthed() -> bool:
	return _stealth_time > 0.0


## An enemy hit us during Counter Ward — reflect damage back, we take none.
func counter_hit(attacker) -> void:
	if attacker != null and attacker.has_method("take_damage"):
		attacker.take_damage(_counter_dmg)
	_spawn_burst(global_position + Vector3.UP * 1.0, 0.7, ARCANE_COL, 8)


## Heal the player (Life Siphon), clamped to max, with a floating number.
func heal(amount: int) -> void:
	if amount <= 0:
		return
	health = clampi(health + amount, 0, max_health)
	DamageNumber.spawn(get_tree().current_scene, global_position + Vector3.UP * 1.4, amount)


## Apply the active +damage buff to a base damage value (for spells and melee).
func _amp(base: int) -> int:
	if _power_time > 0.0:
		return maxi(1, int(round(float(base) * (1.0 + _power_amt))))
	return base


func _update_stamina(delta: float) -> void:
	if is_sprinting:
		stamina -= SPRINT_DRAIN * delta
		_regen_delay = REGEN_DELAY
	elif _regen_delay > 0.0:
		_regen_delay -= delta
	else:
		stamina += get_stamina_regen() * delta
	stamina = clampf(stamina, 0.0, max_stamina)


## Cast a slotted spell when its ability key (ability_1..5 = Q/R/F/C/V) is pressed,
## if its slot is off cooldown and there's enough stamina. Each slot is independent.
func _handle_abilities() -> void:
	for i in range(mini(MAX_SPELLS, equipped_spells.size())):
		if not Input.is_action_just_pressed("ability_%d" % (i + 1)):
			continue
		if _spell_cd[i] > 0.0:
			continue
		var spell: Dictionary = SPELLS.get(equipped_spells[i], {})
		if spell.is_empty():
			continue
		var cost := int(spell.get("cost", 0))
		if stamina < float(cost):
			continue  # not enough stamina
		stamina -= cost
		_regen_delay = REGEN_DELAY
		_spell_cd[i] = float(spell.get("cd", 1.0))
		_cast_spell(spell)
		break  # one cast per frame


## Rotate the last equipped slot (V) through the entire spell catalog. Lets every
## spell be tested without a loadout UI; respects the 5-equipped limit (it swaps
## what is in slot 5 rather than adding a 6th).
func _cycle_spellbook_slot() -> void:
	var keys: Array = SPELLS.keys()
	if keys.is_empty():
		return
	_book_index = (_book_index + 1) % keys.size()
	equipped_spells[4] = keys[_book_index]
	_spell_cd[4] = 0.0
	print("Spellbook  [V] -> ", str(SPELLS[keys[_book_index]].get("name", "?")))


func _cast_spell(spell: Dictionary) -> void:
	humanoid.play_attack()
	var windup := float(spell.get("windup", 0.0))
	# Scope-in for charged precision shots (Arc Sniper).
	if bool(spell.get("zoom", false)) and camera != null and camera.has_method("zoom_charge"):
		camera.zoom_charge(windup)
	if windup > 0.0:
		# Telegraph + delayed effect: skilled players time/position during windup.
		_telegraph(spell, windup)
		var captured: Dictionary = spell
		get_tree().create_timer(windup).timeout.connect(func(): _run_effect(captured))
	else:
		_run_effect(spell)


func _run_effect(mv: Dictionary) -> void:
	match str(mv["effect"]):
		"projectile": _eff_projectile(mv)
		"cone": _eff_cone(mv)
		"nova": _eff_nova(mv)
		"dash": _eff_dash(mv)
		"meteor": _eff_meteor(mv)
		"strike": _eff_strike(mv)
		"storm": _eff_storm(mv)
		"knockback": _eff_knockback(mv)
		"vertical": _eff_vertical(mv)
		"glide": _eff_glide(mv)
		"pound": _eff_pound(mv)
		"fly": _eff_fly(mv)
		"frost_nova": _eff_frost_nova(mv)
		"debuff": _eff_debuff(mv)
		"shotgun": _eff_shotgun(mv)
		"beam": _eff_beam(mv)
		"rapid": _eff_rapid(mv)
		"teleport": _eff_teleport(mv)
		"structure": _eff_structure(mv)
		"spikes": _eff_spikes(mv)
		"buff": _eff_buff(mv)
		"blizzard": _eff_blizzard(mv)
		"quake": _eff_quake(mv)
		"shower": _eff_shower(mv)
		"summon": _eff_summon(mv)
		"zone": _eff_zone(mv)
		"drain": _eff_drain(mv)
		"curse": _eff_curse(mv)
		"reflect": _eff_reflect(mv)
		"decoy": _eff_decoy(mv)
		"chain": _eff_chain(mv)
		"stealth": _eff_stealth(mv)
		"reveal": _eff_reveal(mv)
		"pull": _eff_pull(mv)
		"totem": _eff_totem(mv)
		"heal_zone": _eff_heal_zone(mv)
		"channel": _eff_channel(mv)
		"aura": _eff_aura(mv)


func _telegraph(mv: Dictionary, t: float) -> void:
	var col: Color = mv.get("color", Color(1, 1, 1))
	match str(mv["effect"]):
		"meteor":
			# Fix the landing point NOW so the indicator and impact match exactly.
			_meteor_target = _meteor_landing()
			# Keep the indicator up through the windup AND the fall.
			_spawn_ground_indicator(_meteor_target, float(mv.get("radius", 3.2)), col, t + 0.7)
		"storm":
			_spawn_ring(global_position + _aim_direction() * 6.0 + Vector3.UP * 0.1, 1.6, col, 12)
		"shower", "blizzard":
			_spawn_ground_indicator(global_position + _aim_direction() * 7.0, float(mv.get("radius", 6.0)), col, t + 0.4)
		"quake":
			_spawn_ground_indicator(global_position, float(mv.get("radius", 8.0)), col, t + 0.4)
		_:
			_spawn_ring(global_position + Vector3.UP * 0.1, 1.6, col, 12)


## Raycast straight down in front of the player to find the meteor's ground point.
func _meteor_landing() -> Vector3:
	var aim_xz := global_position + _aim_direction() * 7.0
	var from := Vector3(aim_xz.x, global_position.y + 8.0, aim_xz.z)
	var to := Vector3(aim_xz.x, global_position.y - 30.0, aim_xz.z)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.has("position"):
		return hit["position"]
	return Vector3(aim_xz.x, global_position.y - 0.9, aim_xz.z)


## Flat glowing circle on the ground marking where an AoE will land.
func _spawn_ground_indicator(point: Vector3, radius: float, color: Color, life: float) -> void:
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.05
	disc.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	disc.material_override = mat
	get_tree().current_scene.add_child(disc)
	disc.global_position = point + Vector3.UP * 0.06
	var tw := disc.create_tween().set_loops()
	tw.tween_property(mat, "emission_energy_multiplier", 6.0, 0.22)
	tw.tween_property(mat, "emission_energy_multiplier", 2.5, 0.22)
	get_tree().create_timer(life).timeout.connect(disc.queue_free)


## Horizontal aim (for dashes / ground-plane effects).
func _aim_direction() -> Vector3:
	var f := _aim_direction_3d()
	f.y = 0.0
	if f.length() > 0.01:
		return f.normalized()
	return -global_transform.basis.z


## Full 3D look direction (for AIMED projectiles — travels up/down with the camera).
func _aim_direction_3d() -> Vector3:
	if camera != null:
		var f: Vector3 = camera.get_forward_direction()
		if f.length() > 0.01:
			return f.normalized()
	return -global_transform.basis.z


## The actual world point ranged attacks aim at: a raycast from the muzzle along
## the true aim direction. Used by the crosshair so it shows where shots will land.
func get_aim_point() -> Vector3:
	var origin := global_position + Vector3.UP * 1.2
	var dir := _aim_direction_3d()
	var to := origin + dir * 80.0
	var q := PhysicsRayQueryParameters3D.create(origin, to)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.has("position"):
		return hit["position"]
	return to


# Fire: aimed fireball(s)
func _eff_projectile(mv: Dictionary) -> void:
	var dir := _aim_direction_3d()
	var count: int = int(mv.get("count", 1))
	var size: float = float(mv.get("size", 1.0))
	var speed: float = float(mv.get("speed", 18.0))
	var dmg: int = _amp(int(mv.get("dmg", 2)))
	var col: Color = mv.get("color", FIRE_COL)
	var packed: PackedScene = load(FIREBALL_SCENE)
	if packed == null:
		return
	var grav := float(mv.get("gravity", 0.0))
	var home := float(mv.get("homing", 0.0))
	var arc := bool(mv.get("arc", false))
	for i in range(count):
		var d := dir
		if count > 1:
			d = dir.rotated(Vector3.UP, lerpf(-0.25, 0.25, float(i) / float(count - 1)))
		if arc:
			d = (d + Vector3.UP * 0.6).normalized()  # lob upward so gravity arcs it down
		var fb = packed.instantiate()
		get_tree().current_scene.add_child(fb)
		fb.global_position = global_position + d * 1.0 + Vector3.UP * 1.2
		fb.setup(d, dmg, speed, size, col, bool(mv.get("pierce", false)))
		var slow_f := float(mv.get("slow", 0.0))
		var knock := float(mv.get("knock", 0.0))
		if (slow_f > 0.0 or knock > 0.0) and fb.has_method("set_on_hit"):
			fb.set_on_hit(slow_f, float(mv.get("slow_dur", 2.0)), knock)
		if fb.has_method("set_motion"):
			fb.set_motion(grav, home, true)  # single shots get a glowing trail
		var er := float(mv.get("explode_radius", 0.0))
		if er > 0.0 and fb.has_method("set_explode"):
			fb.set_explode(er, col)
	# Muzzle flash.
	_spawn_burst(global_position + dir * 1.0 + Vector3.UP * 1.2, 0.4, col, 4)


# Fire: a burning rock falls onto the telegraphed point and explodes (AoE).
func _eff_meteor(mv: Dictionary) -> void:
	var landing := _meteor_target  # fixed during the windup telegraph
	var packed: PackedScene = load(METEOR_SCENE)
	if packed == null:
		return
	var m = packed.instantiate()
	get_tree().current_scene.add_child(m)
	m.global_position = Vector3(landing.x, landing.y + 12.0, landing.z)
	m.setup(landing, _amp(int(mv.get("dmg", 9))), float(mv.get("radius", 3.2)), float(mv.get("size", 2.0)), mv.get("color", FIRE_COL))


# Short forward cone/shockwave that damages enemies in an arc in front
func _eff_cone(mv: Dictionary) -> void:
	var rng: float = float(mv.get("range", 4.5))
	var half := deg_to_rad(float(mv.get("angle", 55.0)) * 0.5)
	var dmg: int = _amp(int(mv.get("dmg", 3)))
	var col: Color = mv.get("color", FIRE_COL)
	var dir := _aim_direction()
	for e in get_tree().get_nodes_in_group("enemies"):
		var to_e: Vector3 = e.global_position - global_position
		if to_e.length() > rng:
			continue
		var flat := Vector3(to_e.x, 0, to_e.z)
		if flat.length() < 0.01 or dir.dot(flat.normalized()) < cos(half):
			continue
		if e.has_method("take_damage"):
			e.take_damage(dmg)
	# Visual: a fan of flames sweeping forward in a cone.
	var right := Vector3(dir.z, 0.0, -dir.x)
	for i in range(9):
		var f := lerpf(-1.0, 1.0, float(i) / 8.0)
		var fan := (dir + right * f * 0.9).normalized()
		_spawn_emitter(global_position + Vector3.UP * 0.8 + dir * 0.8, col, 0.17, 0.35, fan * rng)


# Ring/nova of energy around the player damaging everything nearby
func _eff_nova(mv: Dictionary) -> void:
	var radius: float = float(mv.get("radius", 3.5))
	var dmg: int = _amp(int(mv.get("dmg", 3)))
	var col: Color = mv.get("color", FIRE_COL)
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) <= radius and e.has_method("take_damage"):
			e.take_damage(dmg)
	_spawn_ring(global_position + Vector3.UP * 0.4, radius, col, 14)


# Lightning: strike the N nearest enemies in front (from above)
func _eff_strike(mv: Dictionary) -> void:
	var dmg: int = _amp(int(mv.get("dmg", 3)))
	var targets: int = int(mv.get("targets", 1))
	var enemies := _enemies_in_front(_aim_direction_3d())
	if enemies.is_empty():
		_spawn_lightning_strike(global_position + _aim_direction() * 6.0)
		return
	for i in range(mini(targets, enemies.size())):
		var e = enemies[i]
		if e.has_method("take_damage"):
			e.take_damage(dmg)
		_spawn_lightning_strike(e.global_position)


# Lightning: a scatter of strikes raining over an area in front
func _eff_storm(mv: Dictionary) -> void:
	var count: int = int(mv.get("count", 6))
	var spread: float = float(mv.get("spread", 6.0))
	var dmg: int = _amp(int(mv.get("dmg", 3)))
	var center := global_position + _aim_direction() * 6.0
	for i in range(count):
		var p := center + Vector3(randf_range(-spread, spread), 0, randf_range(-spread, spread))
		_spawn_lightning_strike(p)
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.global_position.distance_to(p) <= 2.0 and e.has_method("take_damage"):
				e.take_damage(dmg)


## Enemies within range and roughly in front, sorted nearest-first.
func _enemies_in_front(dir: Vector3) -> Array:
	var list: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		var to_e: Vector3 = e.global_position - global_position
		var d := to_e.length()
		if d > LIGHTNING_RANGE:
			continue
		if dir.dot(to_e.normalized()) < 0.3:
			continue
		list.append(e)
	list.sort_custom(func(a, b):
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	return list


## Lightning STRIKES DOWN from high above the target (a vertical bolt), plus a
## brief flash of light at the impact point.
func _spawn_lightning_strike(point: Vector3) -> void:
	var top := point + Vector3.UP * 7.0
	var bottom := point + Vector3.UP * 0.1
	var col := Color(0.7, 0.85, 1.0)
	# Jagged segmented bolt (zig-zags on the way down) instead of one straight bar.
	var segs := 5
	var prev := top
	for i in range(segs):
		var t := float(i + 1) / float(segs)
		var nxt := top.lerp(bottom, t)
		if i < segs - 1:
			nxt += Vector3(randf_range(-0.45, 0.45), 0.0, randf_range(-0.45, 0.45))
		_bolt_segment(prev, nxt, col)
		prev = nxt

	var flash := OmniLight3D.new()
	flash.light_color = Color(0.6, 0.8, 1.0)
	flash.light_energy = 5.0
	flash.omni_range = 6.0
	get_tree().current_scene.add_child(flash)
	flash.global_position = point + Vector3.UP * 0.5
	get_tree().create_timer(0.18).timeout.connect(flash.queue_free)
	_spawn_ring(point + Vector3.UP * 0.1, 1.1, col, 8)


## One bright glowing segment of a lightning bolt between two points.
func _bolt_segment(a: Vector3, b: Vector3, col: Color) -> void:
	var seg_len := a.distance_to(b)
	if seg_len < 0.01:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.12, seg_len)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.96, 1.0)
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 7.0
	mi.material_override = mat
	get_tree().current_scene.add_child(mi)
	mi.global_position = (a + b) * 0.5
	var up := Vector3.UP
	if absf((b - a).normalized().y) > 0.99:
		up = Vector3.FORWARD
	mi.look_at(b, up)
	get_tree().create_timer(0.18).timeout.connect(mi.queue_free)


# Damages enemies along the dash PATH (each once) and leaves a flame trail, for the
# short window after a Flame Dash. Driven from _physics_process.
func _update_trail(delta: float) -> void:
	if _trail_time <= 0.0:
		return
	_trail_time -= delta
	_spawn_emitter(global_position + Vector3.UP * 0.5, _trail_color, 0.2, 0.4, Vector3.UP * 0.5)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e in _trail_hit:
			continue
		if global_position.distance_to(e.global_position) <= 2.0 and e.has_method("take_damage"):
			_trail_hit.append(e)
			e.take_damage(_trail_dmg)


# Wind/sky/fire: a quick dash burst. Optional fire "trail" or lightning "strike".
func _eff_dash(mv: Dictionary) -> void:
	var spd: float = float(mv.get("speed", 16.0))
	var dir := Vector3(velocity.x, 0.0, velocity.z)
	if dir.length() < 0.5:
		dir = _aim_direction()
	dir = dir.normalized()
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	humanoid.play_roll()  # visible roll animation
	if bool(mv.get("trail", false)):
		# Start a trail that follows the player for the dash, damaging along the path.
		_trail_time = 0.35
		_trail_color = mv.get("color", FIRE_COL)
		_trail_dmg = _amp(int(mv.get("dmg", 2)))
		_trail_hit.clear()
	if bool(mv.get("strike", false)):
		var enemies := _enemies_in_front(_aim_direction_3d())
		if not enemies.is_empty():
			var e = enemies[0]
			if e.has_method("take_damage"):
				e.take_damage(_amp(int(mv.get("dmg", 4))))
			_spawn_lightning_strike(e.global_position)


# Wind: push nearby enemies away (forward cone, or radial for Cyclone)
func _eff_knockback(mv: Dictionary) -> void:
	var rng: float = float(mv.get("range", 5.0))
	var force: float = float(mv.get("force", 14.0))
	var dmg: int = _amp(int(mv.get("dmg", 1)))
	var radial: bool = bool(mv.get("radial", false))
	var col: Color = mv.get("color", WIND_COL)
	var dir := _aim_direction()
	for e in get_tree().get_nodes_in_group("enemies"):
		var to_e: Vector3 = e.global_position - global_position
		var flat := Vector3(to_e.x, 0, to_e.z)
		if flat.length() > rng:
			continue
		if not radial and (flat.length() < 0.01 or dir.dot(flat.normalized()) < 0.3):
			continue
		if e.has_method("take_damage"):
			e.take_damage(dmg)
		var push := (flat.normalized() if flat.length() > 0.01 else dir) * force
		if e.has_method("apply_knockback"):
			e.apply_knockback(push)
	if radial:
		_spawn_ring(global_position + Vector3.UP * 0.5, rng * 0.7, col, 16)  # cyclone
	else:
		# Gust: puffs blasting forward.
		for i in range(8):
			var off := Vector3(randf_range(-0.6, 0.6), randf_range(0.2, 1.0), 0.0)
			_spawn_emitter(global_position + Vector3.UP * 0.7 + dir * (0.6 + i * 0.15) + off, col, 0.15, 0.4, dir * (rng * 0.8))


# Wind/sky: launch the player upward (with a swirl of wind particles).
func _eff_vertical(mv: Dictionary) -> void:
	velocity.y = float(mv.get("power", 11.0))
	for i in range(8):
		var a := TAU * float(i) / 8.0
		_spawn_emitter(global_position + Vector3(cos(a) * 0.4, 0.0, sin(a) * 0.4), Color(0.75, 0.95, 1.0), 0.14, 0.5, Vector3.UP * 3.0)


# Sky: glide (reduced gravity) for a short time
func _eff_glide(_mv: Dictionary) -> void:
	_glide_time = 1.3


# Sky: toggle Levitate flight. While active, gravity is off and movement is full 3D
# (see _update_flight); it drains stamina, and turns off when toggled or stamina runs out.
func _eff_fly(_mv: Dictionary) -> void:
	_flying = not _flying
	# Disable floor-snap while flying so low passes don't glue us to the ground.
	floor_snap_length = 0.0 if _flying else GROUND_SNAP
	if _flying:
		velocity.y = 4.0  # small lift-off so we clear the ground
		_spawn_ring(global_position + Vector3.UP * 0.3, 1.2, Color(0.82, 0.92, 1.0), 12)
	else:
		_spawn_emitter(global_position + Vector3.UP * 0.4, Color(0.82, 0.92, 1.0), 0.2, 0.4, Vector3.DOWN * 0.6)


## Flight movement: camera-relative 3D flight, jump = ascend, sprint = descend.
## Drains stamina; flight ends when stamina is empty.
func _update_flight(delta: float) -> void:
	stamina -= FLY_DRAIN * delta
	_regen_delay = REGEN_DELAY
	is_sprinting = false
	if stamina <= 0.0:
		stamina = 0.0
		_flying = false
		floor_snap_length = GROUND_SNAP  # restore ground snapping
		return

	var input := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var dir := Vector3.ZERO
	if camera != null:
		var cam_fwd: Vector3 = camera.get_forward_direction()  # includes pitch -> 3D
		var cam_right: Vector3 = camera.get_right_direction()
		dir = cam_fwd * input.y - cam_right * input.x
	# Vertical control: jump ascends, sprint descends.
	if Input.is_action_pressed("jump"):
		dir += Vector3.UP
	if Input.is_action_pressed("sprint"):
		dir += Vector3.DOWN

	if dir.length() > 1.0:
		dir = dir.normalized()
	# Horizontal at FLY_SPEED, vertical at FLY_VERTICAL.
	velocity = dir * FLY_SPEED
	velocity.y = dir.y * FLY_VERTICAL
	move_and_slide()

	# Levitation wisps trailing below.
	if Engine.get_physics_frames() % 4 == 0:
		_spawn_emitter(global_position + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3)), Color(0.82, 0.92, 1.0), 0.1, 0.4, Vector3.DOWN * 0.6)


# Sky: slam down; AoE damage resolves on landing (see _physics_process)
func _eff_pound(mv: Dictionary) -> void:
	if is_on_floor():
		return
	velocity.y = -28.0
	_pounding = true
	_pound_params = mv


func _resolve_pound() -> void:
	var radius: float = float(_pound_params.get("radius", 4.0))
	var dmg: int = _amp(int(_pound_params.get("dmg", 5)))
	var col: Color = _pound_params.get("color", SKY_COL)
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) <= radius and e.has_method("take_damage"):
			e.take_damage(dmg)
	_spawn_ring(global_position + Vector3.UP * 0.3, radius, col, 14)


# ============================================================================
#  New spell effects — ice / earth / gun-style / buffs / structures / ultimates
# ============================================================================

## Raycast down to find the ground height at an XZ position (for placing AoEs/props).
func _ground_y(pos: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(pos.x, pos.y + 30.0, pos.z), Vector3(pos.x, pos.y - 60.0, pos.z))
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.has("position"):
		return float(hit["position"].y)
	return pos.y


# Ice: ring nova that damages AND slows nearby enemies.
func _eff_frost_nova(mv: Dictionary) -> void:
	var radius: float = float(mv.get("radius", 4.0))
	var dmg: int = _amp(int(mv.get("dmg", 3)))
	var slow_f: float = float(mv.get("slow", 0.5))
	var slow_d: float = float(mv.get("slow_dur", 3.0))
	var col: Color = mv.get("color", ICE_COL)
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) <= radius:
			if e.has_method("take_damage"):
				e.take_damage(dmg)
			if e.has_method("apply_slow"):
				e.apply_slow(slow_f, slow_d)
	_spawn_ring(global_position + Vector3.UP * 0.4, radius, col, 16)


# Utility/control: apply a status (slow / root / fear) to enemies in an aimed area.
func _eff_debuff(mv: Dictionary) -> void:
	var radius: float = float(mv.get("radius", 5.0))
	var status: String = str(mv.get("status", "slow"))
	var dur: float = float(mv.get("duration", 2.0))
	var col: Color = mv.get("color", ICE_COL)
	var aim := global_position + _aim_direction() * (radius * 0.4)
	for e in get_tree().get_nodes_in_group("enemies"):
		if aim.distance_to(e.global_position) > radius:
			continue
		match status:
			"slow":
				if e.has_method("apply_slow"):
					e.apply_slow(float(mv.get("factor", 0.4)), dur)
			"root":
				if e.has_method("apply_root"):
					e.apply_root(dur)
			"fear":
				if e.has_method("apply_fear"):
					e.apply_fear(dur)
	_spawn_ring(aim + Vector3.UP * 0.2, radius, col, 18)


# Gun: shotgun — a burst of short-range pellets in a forward cone.
func _eff_shotgun(mv: Dictionary) -> void:
	var pellets: int = int(mv.get("pellets", 8))
	var spread: float = float(mv.get("spread", 0.5))
	var speed: float = float(mv.get("speed", 28.0))
	var size: float = float(mv.get("size", 0.6))
	var dmg: int = _amp(int(mv.get("dmg", 3)))
	var slow_f: float = float(mv.get("slow", 0.0))
	var col: Color = mv.get("color", FIRE_COL)
	var packed: PackedScene = load(FIREBALL_SCENE)
	if packed == null:
		return
	var base := _aim_direction_3d()
	for i in range(pellets):
		var d := base.rotated(Vector3.UP, randf_range(-spread, spread))
		var right := d.cross(Vector3.UP)
		if right.length() > 0.01:
			d = d.rotated(right.normalized(), randf_range(-spread * 0.5, spread * 0.5))
		var fb = packed.instantiate()
		get_tree().current_scene.add_child(fb)
		fb.global_position = global_position + base * 1.0 + Vector3.UP * 1.2
		fb.setup(d.normalized(), dmg, speed, size, col, false)
		fb.life = 0.35  # short range
		if slow_f > 0.0 and fb.has_method("set_on_hit"):
			fb.set_on_hit(slow_f, float(mv.get("slow_dur", 2.0)), 0.0)
	_spawn_burst(global_position + base * 1.0 + Vector3.UP * 1.2, 0.5, col, 6)


# Gun: sniper — instant hitscan beam dealing big damage to the first enemy in line.
func _eff_beam(mv: Dictionary) -> void:
	var rng: float = float(mv.get("range", 60.0))
	var dmg: int = _amp(int(mv.get("dmg", 16)))
	var col: Color = mv.get("color", LTNG_COL)
	var origin := global_position + Vector3.UP * 1.2
	var dir := _aim_direction_3d()
	var to := origin + dir * rng
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, to)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	var endp := to
	if hit.has("position"):
		endp = hit["position"]
		var body = hit.get("collider")
		if body != null and body.has_method("take_damage"):
			body.take_damage(dmg)
	_spawn_beam(origin, endp, col)


# A thin glowing line that flashes briefly between two points (railgun look).
func _spawn_beam(a: Vector3, b: Vector3, col: Color) -> void:
	var seg_len := a.distance_to(b)
	if seg_len < 0.1:
		return
	var up := Vector3.UP
	if absf((b - a).normalized().y) > 0.99:
		up = Vector3.FORWARD
	# Outer glow + bright thin core for a layered energy-beam look.
	_beam_layer((a + b) * 0.5, b, seg_len, 0.16, Color(col.r, col.g, col.b), 3.5, up)
	_beam_layer((a + b) * 0.5, b, seg_len, 0.06, col.lerp(Color(1, 1, 1), 0.6), 8.0, up)
	# Impact flash at the far end.
	var flash := OmniLight3D.new()
	flash.light_color = col
	flash.light_energy = 4.0
	flash.omni_range = 4.0
	get_tree().current_scene.add_child(flash)
	flash.global_position = b
	get_tree().create_timer(0.18).timeout.connect(flash.queue_free)
	_spawn_burst(b, 0.4, col, 5)


func _beam_layer(mid: Vector3, look_target: Vector3, seg_len: float, thick: float, col: Color, energy: float, up: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(thick, thick, seg_len)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = energy
	mi.material_override = mat
	get_tree().current_scene.add_child(mi)
	mi.global_position = mid
	mi.look_at(look_target, up)
	var tw := mi.create_tween()
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.18)
	tw.tween_callback(mi.queue_free)


# Gun: rapid-fire — several quick weak shots over a short interval.
func _eff_rapid(mv: Dictionary) -> void:
	var shots: int = int(mv.get("shots", 6))
	var interval: float = float(mv.get("interval", 0.08))
	for i in range(shots):
		var captured: Dictionary = mv
		get_tree().create_timer(interval * float(i)).timeout.connect(func(): _rapid_shot(captured))


func _rapid_shot(mv: Dictionary) -> void:
	var packed: PackedScene = load(FIREBALL_SCENE)
	if packed == null:
		return
	var dir := _aim_direction_3d().rotated(Vector3.UP, randf_range(-0.06, 0.06))
	var fb = packed.instantiate()
	get_tree().current_scene.add_child(fb)
	fb.global_position = global_position + dir * 1.0 + Vector3.UP * 1.2
	fb.setup(dir, _amp(int(mv.get("dmg", 2))), float(mv.get("speed", 38.0)), float(mv.get("size", 0.5)), mv.get("color", LTNG_COL), false)


# Mobility: blink — teleport along the aim (clamped so we don't warp into terrain).
func _eff_teleport(mv: Dictionary) -> void:
	var rng: float = float(mv.get("range", 12.0))
	var col: Color = mv.get("color", ARCANE_COL)
	var dir := _aim_direction()
	var start := global_position
	var origin := global_position + Vector3.UP * 1.0
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * rng)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	var dest := origin + dir * rng
	if hit.has("position"):
		dest = (hit["position"] as Vector3) - dir * 1.0  # stop short of the wall
	dest.y = start.y
	# Settle onto the ground at the destination.
	var dh := space.intersect_ray(PhysicsRayQueryParameters3D.create(dest + Vector3.UP * 4.0, dest - Vector3.UP * 20.0))
	if dh.has("position"):
		dest = (dh["position"] as Vector3) + Vector3.UP * 0.1
	_spawn_burst(start + Vector3.UP * 1.0, 0.6, col, 8)
	global_position = dest
	_spawn_burst(global_position + Vector3.UP * 1.0, 0.6, col, 8)


# Structure: a temporary solid (wall / ramp / platform) that blocks movement and
# auto-removes after `life` seconds. Uses a BoxShape collider (works with Jolt).
func _eff_structure(mv: Dictionary) -> void:
	var kind: String = str(mv.get("structure", "wall"))
	var dims: Vector3 = mv.get("size", Vector3(3.0, 2.4, 1.0))
	var life: float = float(mv.get("life", 8.0))
	var col: Color = mv.get("color", EARTH_COL)
	var dir := _aim_direction()
	var pos := global_position + dir * 2.5
	pos.y = _ground_y(pos)

	var body := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dims
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	mat.emission_enabled = true
	mat.emission = col * 0.4
	mat.emission_energy_multiplier = 0.6
	mesh.material_override = mat
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = dims
	shape.shape = bs
	body.add_child(mesh)
	body.add_child(shape)
	get_tree().current_scene.add_child(body)

	if kind == "platform":
		body.global_position = pos + Vector3.UP * 2.2
	else:
		body.global_position = pos + Vector3.UP * (dims.y * 0.5)
		body.look_at(body.global_position + dir, Vector3.UP)
		if kind == "ramp":
			body.rotate_object_local(Vector3.RIGHT, deg_to_rad(22.0))

	# Rise-from-ground spawn + auto-despawn.
	var final_pos := body.global_position
	body.global_position = final_pos - Vector3.UP * dims.y
	var tw := body.create_tween()
	tw.tween_property(body, "global_position", final_pos, 0.25)
	get_tree().create_timer(life).timeout.connect(body.queue_free)


# Earth: a forward line of stone spikes erupts, damaging + launching enemies on it.
func _eff_spikes(mv: Dictionary) -> void:
	var rng_len: float = float(mv.get("range", 8.0))
	var width: float = float(mv.get("width", 2.0))
	var dmg: int = _amp(int(mv.get("dmg", 5)))
	var col: Color = mv.get("color", EARTH_COL)
	var dir := _aim_direction()
	for e in get_tree().get_nodes_in_group("enemies"):
		var to_e: Vector3 = e.global_position - global_position
		var along := to_e.dot(dir)
		if along < 0.0 or along > rng_len:
			continue
		if (to_e - dir * along).length() <= width:
			if e.has_method("take_damage"):
				e.take_damage(dmg)
			if e.has_method("apply_knockback"):
				e.apply_knockback(Vector3.UP * 4.0)
	var steps := int(rng_len / 1.2)
	for i in range(steps):
		var p := global_position + dir * (1.0 + float(i) * 1.2)
		p.y = _ground_y(p)
		_spawn_spike(p, col)


func _spawn_spike(pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.28
	cone.height = 1.2
	mi.mesh = cone
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	mi.material_override = mat
	get_tree().current_scene.add_child(mi)
	mi.global_position = pos - Vector3.UP * 1.0
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position", pos + Vector3.UP * 0.4, 0.12)
	tw.tween_interval(0.5)
	tw.tween_property(mi, "global_position", pos - Vector3.UP * 1.2, 0.2)
	tw.tween_callback(mi.queue_free)


# Self-buff: apply a timed buff (power / speed / shield / regen) or instant restore.
func _eff_buff(mv: Dictionary) -> void:
	var kind: String = str(mv.get("buff", "power"))
	var amt: float = float(mv.get("amount", 0.5))
	var dur: float = float(mv.get("duration", 12.0))
	var col: Color = mv.get("color", FIRE_COL)
	match kind:
		"power":
			_power_amt = amt
			_power_time = dur
		"speed":
			_speed_amt = amt
			_speed_time = dur
		"shield":
			_shield_amt = clampf(amt, 0.0, 0.9)
			_shield_time = dur
		"regen":
			_regen_buff_amt = amt
			_regen_buff_time = dur
		"restore":
			stamina = clampf(stamina + amt, 0.0, max_stamina)
			health = clampi(health + int(amt * 0.5), 0, max_health)
	for i in range(10):
		var a := TAU * float(i) / 10.0
		_spawn_emitter(global_position + Vector3(cos(a) * 0.5, 0.2, sin(a) * 0.5), col, 0.16, 0.6, Vector3.UP * 1.6)


# Ultimate (ice): a lingering blizzard over the aimed area — repeated damage + slow.
func _eff_blizzard(mv: Dictionary) -> void:
	var center := global_position + _aim_direction() * 7.0
	center.y = _ground_y(center)
	var radius: float = float(mv.get("radius", 6.0))
	var ticks: int = int(mv.get("ticks", 6))
	var dmg: int = _amp(int(mv.get("dmg", 2)))
	var slow_f: float = float(mv.get("slow", 0.5))
	var slow_d: float = float(mv.get("slow_dur", 1.5))
	var col: Color = mv.get("color", ICE_COL)
	for t in range(ticks):
		get_tree().create_timer(float(t) * 0.4).timeout.connect(func(): _blizzard_tick(center, radius, dmg, slow_f, slow_d, col))


func _blizzard_tick(center: Vector3, radius: float, dmg: int, slow_f: float, slow_d: float, col: Color) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if center.distance_to(e.global_position) <= radius:
			if e.has_method("take_damage"):
				e.take_damage(dmg)
			if e.has_method("apply_slow"):
				e.apply_slow(slow_f, slow_d)
	for i in range(8):
		var off := Vector3(randf_range(-radius, radius), randf_range(2.0, 4.0), randf_range(-radius, radius))
		_spawn_emitter(center + off, col, 0.16, 0.6, Vector3.DOWN * 4.0)


# Ultimate (earth): violent earthquake around the player — heavy AoE + launch.
func _eff_quake(mv: Dictionary) -> void:
	var radius: float = float(mv.get("radius", 8.0))
	var dmg: int = _amp(int(mv.get("dmg", 8)))
	var force: float = float(mv.get("force", 14.0))
	var col: Color = mv.get("color", EARTH_COL)
	for e in get_tree().get_nodes_in_group("enemies"):
		var to_e: Vector3 = e.global_position - global_position
		var flat := Vector3(to_e.x, 0.0, to_e.z)
		if flat.length() <= radius:
			if e.has_method("take_damage"):
				e.take_damage(dmg)
			if e.has_method("apply_knockback"):
				var push := (flat.normalized() if flat.length() > 0.01 else _aim_direction())
				e.apply_knockback(push * force + Vector3.UP * (force * 0.6))
	_spawn_ring(global_position + Vector3.UP * 0.2, radius, col, 22)
	for i in range(14):
		var a := randf() * TAU
		var p := global_position + Vector3(cos(a), 0.0, sin(a)) * (randf() * radius)
		p.y = _ground_y(p)
		_spawn_spike(p, col)


# Ultimate (fire): meteor shower — several meteors rain across the aimed area.
func _eff_shower(mv: Dictionary) -> void:
	var center := global_position + _aim_direction() * 7.0
	var count: int = int(mv.get("count", 7))
	var spread: float = float(mv.get("spread", 7.0))
	for i in range(count):
		var off := Vector3(randf_range(-spread, spread), 0.0, randf_range(-spread, spread))
		var target := center + off
		target.y = _ground_y(target)
		var captured: Dictionary = mv
		get_tree().create_timer(randf() * 0.5).timeout.connect(func(): _spawn_one_meteor(target, captured))


func _spawn_one_meteor(target: Vector3, mv: Dictionary) -> void:
	var packed: PackedScene = load(METEOR_SCENE)
	if packed == null:
		return
	var m = packed.instantiate()
	get_tree().current_scene.add_child(m)
	m.global_position = Vector3(target.x, target.y + 14.0, target.z)
	m.setup(target, _amp(int(mv.get("dmg", 8))), float(mv.get("radius", 3.0)), float(mv.get("size", 1.6)), mv.get("color", FIRE_COL))


# ============================================================================
#  Pass 3 effects — summons / zones / drain / curse / reflect / decoy / chain /
#  stealth / reveal
# ============================================================================

# Summon: spawn a temporary ally (fire elemental or stone golem) that fights for us.
func _eff_summon(mv: Dictionary) -> void:
	var packed: PackedScene = load(MINION_SCENE)
	if packed == null:
		return
	var m = packed.instantiate()
	m.setup(str(mv.get("kind", "fire")), _amp(int(mv.get("dmg", 2))), float(mv.get("life", 12.0)), mv.get("color", FIRE_COL))
	get_tree().current_scene.add_child(m)
	var spawn := global_position + _aim_direction() * 2.0
	spawn.y = _ground_y(spawn)
	m.global_position = spawn
	_spawn_ring(spawn + Vector3.UP * 0.3, 1.0, mv.get("color", FIRE_COL), 12)


# Terrain-altering / area-denial / environmental: a lingering ground (or cloud) zone
# that ticks damage / slow / DoT on enemies inside it. "grow" makes it spread (wildfire).
func _eff_zone(mv: Dictionary) -> void:
	var center := global_position + _aim_direction() * 5.0
	center.y = _ground_y(center)
	var radius := float(mv.get("radius", 4.0))
	var life := float(mv.get("life", 8.0))
	var col: Color = mv.get("color", ICE_COL)
	var opts := {
		"dmg": int(mv.get("dmg", 0)),
		"slow": float(mv.get("slow", 0.0)),
		"slow_dur": float(mv.get("slow_dur", 1.0)),
		"dot": float(mv.get("dot", 0.0)),
		"grow": float(mv.get("grow", 0.0)),
		"color": col,
	}
	_spawn_hazard(center, radius, col, life, float(mv.get("height", 0.06)), opts)


func _spawn_hazard(center: Vector3, radius: float, color: Color, life: float, height: float, opts: Dictionary) -> void:
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.08
	disc.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.2)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.2
	disc.material_override = mat
	get_tree().current_scene.add_child(disc)
	disc.global_position = center + Vector3.UP * height
	var grow := float(opts.get("grow", 0.0))
	var interval := 0.5
	var ticks := int(life / interval)
	for t in range(ticks):
		var cur_r := radius + grow * float(t)
		var cc := center
		var cr := cur_r
		var co := opts
		get_tree().create_timer(interval * float(t)).timeout.connect(func(): _hazard_tick(cc, cr, co))
	if grow > 0.0:
		var final_r := radius + grow * float(ticks)
		var tw := disc.create_tween()
		tw.tween_property(disc, "scale", Vector3(final_r / radius, 1.0, final_r / radius), life)
	get_tree().create_timer(life).timeout.connect(disc.queue_free)


func _hazard_tick(center: Vector3, radius: float, opts: Dictionary) -> void:
	var dmg := int(opts.get("dmg", 0))
	var slow_f := float(opts.get("slow", 0.0))
	var slow_d := float(opts.get("slow_dur", 1.0))
	var dot := float(opts.get("dot", 0.0))
	var col: Color = opts.get("color", Color(1, 1, 1))
	for e in get_tree().get_nodes_in_group("enemies"):
		if center.distance_to(e.global_position) > radius:
			continue
		if dmg > 0 and e.has_method("take_damage"):
			e.take_damage(_amp(dmg))
		if slow_f > 0.0 and e.has_method("apply_slow"):
			e.apply_slow(slow_f, slow_d)
		if dot > 0.0 and e.has_method("apply_dot"):
			e.apply_dot(dot, 1.0)
	for i in range(4):
		var off := Vector3(randf_range(-radius, radius), randf_range(0.1, 0.6), randf_range(-radius, radius))
		_spawn_emitter(center + off, col, 0.12, 0.5, Vector3.UP * 0.4)


# Drain: hit the nearest enemy in front and heal HP (or restore stamina) from it.
func _eff_drain(mv: Dictionary) -> void:
	var dmg := _amp(int(mv.get("dmg", 5)))
	var col: Color = mv.get("color", SHADOW_COL)
	var enemies := _enemies_in_front(_aim_direction_3d())
	if enemies.is_empty():
		return
	var e = enemies[0]
	if e.has_method("take_damage"):
		e.take_damage(dmg)
	if str(mv.get("mode", "health")) == "stamina":
		stamina = clampf(stamina + float(mv.get("gain", 12.0)), 0.0, max_stamina)
	else:
		heal(int(float(dmg) * float(mv.get("ratio", 0.5))))
	_spawn_beam(e.global_position + Vector3.UP * 1.0, global_position + Vector3.UP * 1.0, col)


# Curse / DoT: apply a lingering damage tick (and optional slow) to enemies in an area.
func _eff_curse(mv: Dictionary) -> void:
	var radius := float(mv.get("radius", 4.0))
	var dps := float(mv.get("dps", 4.0))
	var dur := float(mv.get("duration", 4.0))
	var slow_f := float(mv.get("slow", 0.0))
	var col: Color = mv.get("color", SHADOW_COL)
	var center := global_position + _aim_direction() * 5.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if center.distance_to(e.global_position) <= radius:
			if e.has_method("apply_dot"):
				e.apply_dot(dps, dur)
			if slow_f > 0.0 and e.has_method("apply_slow"):
				e.apply_slow(slow_f, dur)
	_spawn_ring(center + Vector3.UP * 0.3, radius, col, 16)


# Reflect / counter: open a short window where melee attackers are damaged and we
# take none (see enemy._try_attack + counter_hit).
func _eff_reflect(mv: Dictionary) -> void:
	_counter_time = float(mv.get("duration", 2.5))
	_counter_dmg = _amp(int(mv.get("dmg", 7)))
	_spawn_ring(global_position + Vector3.UP * 1.0, 1.4, mv.get("color", ARCANE_COL), 14)


# Clone / decoy: spawn a fake copy that enemies target instead of us.
func _eff_decoy(mv: Dictionary) -> void:
	var packed: PackedScene = load(DECOY_SCENE)
	if packed == null:
		return
	var d = packed.instantiate()
	d.setup(float(mv.get("life", 8.0)))
	get_tree().current_scene.add_child(d)
	var pos := global_position + _aim_direction() * 2.0
	pos.y = _ground_y(pos)
	d.global_position = pos
	_spawn_burst(pos + Vector3.UP * 1.0, 0.6, mv.get("color", ARCANE_COL), 8)


# Chain / bounce: a bolt that jumps sequentially between nearby enemies, with falloff.
func _eff_chain(mv: Dictionary) -> void:
	var jumps := int(mv.get("jumps", 5))
	var jump_range := float(mv.get("range", 7.0))
	var col: Color = mv.get("color", LTNG_COL)
	var cur = _nearest_enemy_within(global_position, LIGHTNING_RANGE, [])
	if cur == null:
		return
	var hit: Array = []
	var prev := global_position + Vector3.UP * 1.0
	var cur_dmg := _amp(int(mv.get("dmg", 4)))
	for i in range(jumps):
		if cur == null:
			break
		hit.append(cur)
		if cur.has_method("take_damage"):
			cur.take_damage(cur_dmg)
		if float(mv.get("slow", 0.0)) > 0.0 and cur.has_method("apply_slow"):
			cur.apply_slow(float(mv["slow"]), float(mv.get("slow_dur", 2.0)))
		_spawn_beam(prev, cur.global_position + Vector3.UP * 1.0, col)
		_spawn_burst(cur.global_position + Vector3.UP * 0.8, 0.4, col, 4)
		prev = cur.global_position + Vector3.UP * 1.0
		cur_dmg = maxi(1, int(round(float(cur_dmg) * 0.7)))  # falloff per jump
		cur = _nearest_enemy_within(prev, jump_range, hit)


func _nearest_enemy_within(from: Vector3, radius: float, exclude: Array):
	var best = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if e in exclude:
			continue
		var d := from.distance_to(e.global_position)
		if d < best_d and d <= radius:
			best_d = d
			best = e
	return best


# Stealth: enemies can't see us for a short time (see enemy._find_target).
func _eff_stealth(mv: Dictionary) -> void:
	_stealth_time = float(mv.get("duration", 5.0))
	_spawn_burst(global_position + Vector3.UP * 1.0, 0.8, mv.get("color", SHADOW_COL), 10)


# Detection: ping every nearby enemy with a marker visible through walls.
func _eff_reveal(mv: Dictionary) -> void:
	var radius := float(mv.get("radius", 35.0))
	var dur := float(mv.get("duration", 6.0))
	var col: Color = mv.get("color", ARCANE_COL)
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) <= radius:
			_spawn_marker(e, dur, col)


func _spawn_marker(enemy: Node3D, dur: float, col: Color) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.6
	sm.radial_segments = 6
	sm.rings = 3
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 6.0
	mat.no_depth_test = true  # visible through walls/terrain
	m.material_override = mat
	enemy.add_child(m)
	m.position = Vector3.UP * 2.4
	var tw := m.create_tween().set_loops()
	tw.tween_property(m, "position:y", 2.7, 0.5)
	tw.tween_property(m, "position:y", 2.4, 0.5)
	get_tree().create_timer(dur).timeout.connect(_free_node.bind(m))


## Free a node only if it still exists (markers may already be gone with their enemy).
func _free_node(n: Node) -> void:
	if is_instance_valid(n):
		n.queue_free()


# ============================================================================
#  Pass 4 effects — pull / totem / heal-zone / channel / aura
# ============================================================================

## A persistent glowing orb in the world (for totems / singularities).
func _make_orb(pos: Vector3, r: float, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 4.0
	m.material_override = mat
	get_tree().current_scene.add_child(m)
	m.global_position = pos
	return m


# Singularity: a vacuum point that drags enemies inward over several ticks + chip dmg.
func _eff_pull(mv: Dictionary) -> void:
	var center := global_position + _aim_direction() * 6.0
	center.y = _ground_y(center) + 1.0
	var radius := float(mv.get("radius", 7.0))
	var force := float(mv.get("force", 9.0))
	var ticks := int(mv.get("ticks", 8))
	var dmg := _amp(int(mv.get("dmg", 2)))
	var col: Color = mv.get("color", ARCANE_COL)
	var core := _make_orb(center, 0.6, col)
	var tw := core.create_tween().set_loops()
	tw.tween_property(core, "scale", Vector3.ONE * 1.3, 0.4)
	tw.tween_property(core, "scale", Vector3.ONE * 0.8, 0.4)
	for t in range(ticks):
		get_tree().create_timer(float(t) * 0.25).timeout.connect(func(): _pull_tick(center, radius, force, dmg))
	get_tree().create_timer(float(ticks) * 0.25 + 0.1).timeout.connect(core.queue_free)


func _pull_tick(center: Vector3, radius: float, force: float, dmg: int) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		var flat := Vector3(center.x - e.global_position.x, 0.0, center.z - e.global_position.z)
		if flat.length() <= radius and flat.length() > 0.4:
			if e.has_method("apply_knockback"):
				e.apply_knockback(flat.normalized() * force)
			if e.has_method("take_damage"):
				e.take_damage(dmg)
	for i in range(3):
		var a := randf() * TAU
		var edge := center + Vector3(cos(a) * radius * 0.7, randf_range(0.2, 1.0), sin(a) * radius * 0.7)
		_spawn_emitter(edge, Color(0.7, 0.5, 1.0), 0.12, 0.35, (center - edge) * 0.8)


# Storm Totem: a deployed pylon that zaps the nearest enemy in range periodically.
func _eff_totem(mv: Dictionary) -> void:
	var pos := global_position + _aim_direction() * 2.5
	pos.y = _ground_y(pos)
	var col: Color = mv.get("color", LTNG_COL)
	var life := float(mv.get("life", 8.0))
	var pylon := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.2
	cyl.height = 1.6
	pylon.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col.darkened(0.3)
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.0
	pylon.material_override = mat
	get_tree().current_scene.add_child(pylon)
	pylon.global_position = pos + Vector3.UP * 0.8
	var orb := _make_orb(pos + Vector3.UP * 1.7, 0.18, col)
	var rng := float(mv.get("range", 9.0))
	var dmg := _amp(int(mv.get("dmg", 3)))
	var interval := float(mv.get("interval", 0.8))
	var ticks := int(life / interval)
	for t in range(ticks):
		get_tree().create_timer(float(t) * interval).timeout.connect(func(): _totem_tick(pos + Vector3.UP * 1.7, rng, dmg, col))
	get_tree().create_timer(life).timeout.connect(pylon.queue_free)
	get_tree().create_timer(life).timeout.connect(orb.queue_free)


func _totem_tick(from: Vector3, rng: float, dmg: int, col: Color) -> void:
	var best = null
	var bd := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var d := from.distance_to(e.global_position)
		if d < bd and d <= rng:
			bd = d
			best = e
	if best == null:
		return
	if best.has_method("take_damage"):
		best.take_damage(dmg)
	_spawn_beam(from, best.global_position + Vector3.UP * 1.0, col)


# Sanctuary: a zone that heals the player while standing in it.
func _eff_heal_zone(mv: Dictionary) -> void:
	var center := global_position
	center.y = _ground_y(center)
	var radius := float(mv.get("radius", 4.0))
	var life := float(mv.get("life", 8.0))
	var amt := int(mv.get("heal", 4))
	var col: Color = mv.get("color", NATURE_COL)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.06
	disc.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col.darkened(0.2)
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.4
	disc.material_override = mat
	get_tree().current_scene.add_child(disc)
	disc.global_position = center + Vector3.UP * 0.06
	var ticks := int(life / 0.7)
	for t in range(ticks):
		get_tree().create_timer(float(t) * 0.7).timeout.connect(func(): _heal_zone_tick(center, radius, amt, col))
	get_tree().create_timer(life).timeout.connect(disc.queue_free)


func _heal_zone_tick(center: Vector3, radius: float, amt: int, col: Color) -> void:
	if center.distance_to(global_position) <= radius:
		heal(amt)
		for i in range(4):
			var a := TAU * float(i) / 4.0
			_spawn_emitter(global_position + Vector3(cos(a) * 0.4, 0.2, sin(a) * 0.4), col, 0.12, 0.5, Vector3.UP * 1.2)


# Tempest: a short channelled vortex around the player — pulls enemies in + ticks dmg.
func _eff_channel(mv: Dictionary) -> void:
	var radius := float(mv.get("radius", 4.5))
	var ticks := int(mv.get("ticks", 8))
	var dmg := _amp(int(mv.get("dmg", 2)))
	var force := float(mv.get("force", 6.0))
	var col: Color = mv.get("color", WIND_COL)
	for t in range(ticks):
		get_tree().create_timer(float(t) * 0.15).timeout.connect(func(): _tempest_tick(radius, dmg, force, col))


func _tempest_tick(radius: float, dmg: int, force: float, col: Color) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		var flat := Vector3(global_position.x - e.global_position.x, 0.0, global_position.z - e.global_position.z)
		if flat.length() <= radius and flat.length() > 0.3:
			if e.has_method("apply_knockback"):
				var tang := Vector3(-flat.z, 0.0, flat.x).normalized()
				e.apply_knockback(flat.normalized() * force * 0.5 + tang * force * 0.5)
			if e.has_method("take_damage"):
				e.take_damage(dmg)
	for i in range(6):
		var a := TAU * float(i) / 6.0 + float(Engine.get_physics_frames()) * 0.1
		_spawn_emitter(global_position + Vector3(cos(a) * radius * 0.8, randf_range(0.2, 1.4), sin(a) * radius * 0.8), col, 0.13, 0.3, Vector3.UP * 0.6)


# Cinder Aura: enable the timed damaging aura (ticked in _update_buffs).
func _eff_aura(mv: Dictionary) -> void:
	_aura_time = float(mv.get("duration", 8.0))
	_aura_radius = float(mv.get("radius", 3.5))
	_aura_dot = float(mv.get("dot", 3.0))
	_aura_color = mv.get("color", FIRE_COL)
	_aura_tick = 0.0
	_spawn_ring(global_position + Vector3.UP * 0.4, _aura_radius, _aura_color, 16)


# --- Ability VFX (brief code-only emissive primitives) ---

## A glowing particle that drifts, shrinks and dims, then frees itself. Uses a
## shared low-poly mesh and an OPAQUE material (no transparent pass) to keep ability
## use stutter-free.
func _spawn_emitter(pos: Vector3, color: Color, sz: float, life: float, drift: Vector3 = Vector3.ZERO) -> void:
	var m := MeshInstance3D.new()
	m.mesh = _fx_sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	m.material_override = mat
	get_tree().current_scene.add_child(m)
	m.global_position = pos
	m.scale = Vector3.ONE * sz  # unit sphere scaled to the requested size
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * sz * 0.05, life)
	tw.tween_property(m, "global_position", pos + drift, life)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, life)
	tw.chain().tween_callback(m.queue_free)


func _spawn_burst(center: Vector3, radius: float, color: Color, count: int) -> void:
	for i in range(count):
		var off := Vector3(randf_range(-radius, radius), randf_range(-0.2, 0.6), randf_range(-radius, radius))
		_spawn_emitter(center + off, color, 0.16, 0.45, Vector3.UP * 0.8)


## Expanding ring of particles (start near center, drift outward).
func _spawn_ring(center: Vector3, radius: float, color: Color, count: int) -> void:
	for i in range(count):
		var a := TAU * float(i) / float(count)
		var outd := Vector3(cos(a), 0.0, sin(a))
		_spawn_emitter(center + outd * radius * 0.4, color, 0.14, 0.5, outd * radius * 0.6)


# --- Health ---

## Take damage from goblins/orcs (or anything), show a floating number, and respawn
## at the village if we hit 0 HP.
func take_damage(amount: int) -> void:
	if _shield_time > 0.0:
		amount = maxi(0, int(round(float(amount) * (1.0 - _shield_amt))))  # Stone Skin
	health = max(0, health - amount)
	DamageNumber.spawn(get_tree().current_scene, global_position + Vector3.UP * 1.1, amount)
	if health <= 0:
		_respawn()


func _respawn() -> void:
	health = max_health
	stamina = max_stamina
	_flying = false
	floor_snap_length = GROUND_SNAP
	_power_time = 0.0
	_speed_time = 0.0
	_shield_time = 0.0
	_regen_buff_time = 0.0
	_counter_time = 0.0
	_stealth_time = 0.0
	_aura_time = 0.0
	global_position = Vector3(0.0, 4.0, 0.0)
	velocity = Vector3.ZERO


# --- Inventory ---

## Add an item (dictionary) to the inventory.
func add_item(item: Dictionary) -> void:
	inventory.append(item)


## Equip an item into its slot. Only the "weapon" slot is functional right now:
## it spawns the weapon model and places it in the character's hand.
func equip(item: Dictionary) -> void:
	var slot: String = item.get("slot", "")
	if not equipment.has(slot):
		return
	equipment[slot] = item

	if slot == "weapon":
		if equipped_weapon != null:
			equipped_weapon.queue_free()
			equipped_weapon = null
		var scene_path: String = item.get("scene", "")
		if scene_path != "":
			var packed: PackedScene = load(scene_path)
			if packed != null:
				var weapon: Node3D = packed.instantiate()
				humanoid.attach_to_hand(weapon)
				equipped_weapon = weapon

	# Reflect armor (helmet/chest/legs) on the 3D character.
	humanoid.apply_equipment(equipment)

	# The staff sets a fixed melee reach; recompute passive max health.
	attack_hitbox.scale = Vector3.ONE * STAFF_REACH
	max_health = get_max_health()
	health = min(health, max_health)
