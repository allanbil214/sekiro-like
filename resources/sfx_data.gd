class_name SfxData
extends Resource
## The sound table (Step 11a): `audio/sfx_data.tres` holds one SfxSlot per sound. Edit the wavs, volumes,
## and pitches in the Inspector. `Sfx` loads this file once.

@export var slots: Array[SfxSlot] = []
## Added to every sound (dB). A quick master volume for the game's own sounds.
@export var master_volume_db: float = 0.0
## How far a positional sound carries (AudioStreamPlayer3D.unit_size): bigger = still loud far away.
@export var world_unit_size: float = 15.0
## Slashes that are not combo steps 1 to 5 pick the second swing sound this often.
@export_range(0.0, 1.0) var swing_alt_chance: float = 0.25
## The deathblow_opening wavs. Off for now: without the real animation they overlap other sounds.
@export var deathblow_open_enabled: bool = false
