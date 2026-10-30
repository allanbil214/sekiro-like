class_name SoundEvent
extends Resource
## One sound at one moment of an action (Phase 3d-1, frame-driven sound). `ActionData.sound_events` is a list of these: when the
## action clock passes `time` the sound plays once (the player's own sounds flat, an enemy's in the world at its position).
## The sound table decides which wavs the slot has; a slot with several picks one at random (never the same twice in a row),
## with its own small random pitch and level change (`SfxSlot.pitch_min`, `pitch_max`, `volume_jitter_db`).

## Seconds from the start of the action.
@export var time: float = 0.0
## The sound slot (`Sfx.Id`, see `data/audio/sfx_data.tres`).
@export var sound: Sfx.Id = Sfx.Id.SWING
## Added to the slot's loudness (dB).
@export var volume_db: float = 0.0
## Multiplies the slot's random pitch (1 = as the slot says).
@export var pitch: float = 1.0
