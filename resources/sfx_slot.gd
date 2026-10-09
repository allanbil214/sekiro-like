class_name SfxSlot
extends Resource
## One sound of the game (Step 11a): which wavs it can play and how loud. `slot_name` must match a
## name in `Sfx.Id` (lowercase, e.g. "deflect"). Several streams = variants, one is picked at random
## (never the same twice in a row). No streams = the slot is silent.

@export var slot_name: String = ""
@export var streams: Array[AudioStream] = []
## Loudness of this slot, in dB (0 = the wav as it is).
@export var volume_db: float = 0.0
## Each play picks a random pitch between these two (1.0 = the wav as it is).
@export var pitch_min: float = 0.97
@export var pitch_max: float = 1.03
## Slots with the same non-empty group share one voice: a new sound of the group cuts the old one
## (a new deflect cuts the old ring, as in Sekiro).
@export var group: StringName = &""
