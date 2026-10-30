"""Phase 3a-3a converter (PLACEHOLDER(ER clip), see docs/placeholders.md, P2 and P3).

Reads the Bevy sandbox's baked clips (`assets/player_anims.bin` of ELDEN-RING-Combat-Rewrite-with-data) and writes only
the clips this project maps to its actions into one compact file, `assets/placeholder/player_clips.bin`, which
`PlaceholderClips` (scripts/placeholder/placeholder_clips.gd) loads. Run it once on the PC:

    python tools/placeholder/convert_clips.py <path to player_anims.bin> [output path]

Source space: +X left, +Y up, +Z forward. Godot: +X right, +Y up, -Z forward, so every point is turned 180 degrees
about Y (x and z negated): a rotation, not a mirror. The oriented joints' axes (Head, R_Weapon, L_Weapon) turn the same way.

Output (little endian): b"PCLP", u32 version (1), u32 joint count, u32 oriented count, u32 clip count; the joint names
and the oriented names (a u8 length, then the bytes); then per clip: name (u8 length + bytes), source id (the same),
f32 blend (frames), u32 frame count, and frames x (joints x 3 + oriented x 9) f32 (positions in m, then each oriented
joint's X, Y and Z axes). 30 frames per second.
"""
import struct
import sys
from pathlib import Path

# Our name -> the sandbox clip. The clips of the one-handed uchigatana set (a029) and the base movement set (a000).
# The uchigatana has no crouch attack, so the curved sword's (a028) stands in: PLACEHOLDER(ER clip) either way.
CLIPS = {
    "combo_1": "a029_030000", "combo_2": "a029_030010", "combo_3": "a029_030020",
    "combo_4": "a029_030030", "combo_5": "a029_030040",
    "heavy1_charge": "a029_030500", "heavy1": "a029_030505",
    "run_attack": "a029_030200",
    "crouch_attack": "a028_030310",
    # 3a-3c-4: the uchigatana's rolling attack, the enemy sweep (hit frames 11 to 14 of 55).
    "dodge_attack": "a029_030300",
    "air_light": "a029_031030", "air_heavy": "a029_031230",
    "air_light_land": "a029_031070", "air_heavy_land": "a029_031270",
    "backstep": "a000_027000",
    "roll_front": "a000_027100", "roll_back": "a000_027101", "roll_left": "a000_027102", "roll_right": "a000_027103",
    "idle": "a000_000000",
    "walk_front": "a000_020000", "walk_back": "a000_020001", "walk_left": "a000_020002", "walk_right": "a000_020003",
    "run_front": "a000_020100", "sprint": "a000_020200",
    "crouch_idle": "a000_300000", "crouch_walk_front": "a000_320000",
    # 3c-2a: the other three run directions and the four crouch-run directions (the locomotion blend by movement angle).
    "run_back": "a000_020101", "run_left": "a000_020102", "run_right": "a000_020103",
    "crouch_run_front": "a000_320100", "crouch_run_back": "a000_320101",
    "crouch_run_left": "a000_320102", "crouch_run_right": "a000_320103",
    # 3c-3a: the jump by take-off speed, the airborne loop, the fall start (walking off a ledge) and the landings.
    "jump_stand": "a000_202000", "jump_walk": "a000_202010", "jump_run": "a000_202020", "jump_sprint": "a000_202030",
    "air_loop": "a000_202040", "fall_start": "a000_004000",
    "land_light": "a000_202100", "land_run": "a000_202127", "land_sprint": "a000_202125",
    "land_fall": "a000_202300", "land_heavy": "a000_202310",
    # 3c-3b-1: the reactions to a hit by strength and the side it came from, and the guard break.
    "hurt_small_front": "a000_005110", "hurt_small_back": "a000_005100", "hurt_small_left": "a000_005120", "hurt_small_right": "a000_005130",
    "hurt_middle_front": "a000_005200", "hurt_middle_back": "a000_005230", "hurt_middle_left": "a000_005220", "hurt_middle_right": "a000_005210",
    "hurt_large_front": "a000_005300", "hurt_large_back": "a000_005310", "hurt_large_left": "a000_005330", "hurt_large_right": "a000_005320",
    "hurt_knockdown_front": "a000_005400", "hurt_knockdown_back": "a000_005410", "hurt_knockdown_left": "a000_005420", "hurt_knockdown_right": "a000_005430",
    "guard_break": "a000_004270",
}


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    source = Path(sys.argv[1])
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).resolve().parents[2] / "assets" / "placeholder" / "player_clips.bin"
    data = source.read_bytes()
    if data[:4] != b"ERAN":
        sys.exit("not a player_anims.bin (missing the ERAN header)")
    joint_count, oriented_count, clip_count = struct.unpack_from("<III", data, 4)
    pos = 16

    def read_name() -> str:
        nonlocal pos
        length = data[pos]
        text = data[pos + 1:pos + 1 + length].decode()
        pos += 1 + length
        return text

    joints = [read_name() for _ in range(joint_count)]
    oriented = [read_name() for _ in range(oriented_count)]
    stride = joint_count * 3 + oriented_count * 9
    found: dict[str, tuple[float, int, list[float]]] = {}
    wanted = set(CLIPS.values())
    for _ in range(clip_count):
        name = read_name()
        blend, frames = struct.unpack_from("<fI", data, pos)
        pos += 8
        size = frames * stride
        if name in wanted:
            found[name] = (blend, frames, list(struct.unpack_from("<%df" % size, data, pos)))
        pos += size * 4
    missing = [f"{ours} ({theirs})" for ours, theirs in CLIPS.items() if theirs not in found]
    if missing:
        sys.exit("clips missing from the bin: " + ", ".join(missing))

    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "wb") as f:
        f.write(b"PCLP")
        f.write(struct.pack("<IIII", 1, joint_count, oriented_count, len(CLIPS)))
        for group in (joints, oriented):
            for joint in group:
                raw = joint.encode()
                f.write(struct.pack("<B", len(raw)) + raw)
        for ours, theirs in CLIPS.items():
            blend, frames, values = found[theirs]
            for index in range(len(values)):
                column = index % 3 if index < joint_count * 3 else (index - joint_count * 3) % 3
                if column != 1:  # the 180 degree turn about Y: x and z change sign, y stays
                    values[index] = -values[index]
            for text in (ours, theirs):
                raw = text.encode()
                f.write(struct.pack("<B", len(raw)) + raw)
            f.write(struct.pack("<fI", blend, frames))
            f.write(struct.pack("<%df" % len(values), *values))
    print("wrote", out, out.stat().st_size, "bytes,", len(CLIPS), "clips")


if __name__ == "__main__":
    main()
