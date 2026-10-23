class_name RestPointKind
extends Resource
## One kind of rest point (Phase 2 item 18): a shrine, a clinic, a camp, an inn. Only words differ between the
## kinds; what resting does is the same everywhere (`RestPoint`, `RestState`). The look is the scene of the kind
## (for example `rest_point_inari.tscn`). A cost, a shop or saving join in later phases.

## What the kind is called ("Inari shrine").
@export var kind_name: String = "Rest point"
## The verb on the interact prompt ("Pray", "Rest", "Camp", "Get treated"). A placed rest point may override it.
@export var prompt_verb: String = "Rest"
## The line shown when the rest is over.
@export_multiline var flavor_line: String = "You rest a while."
