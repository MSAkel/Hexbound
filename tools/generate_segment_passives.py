"""One-shot generator for segment passive .tres files. Not used at runtime."""

from pathlib import Path

ROOT = Path(r"e:\Godot\game++\resources\segment_passives")
UNLOCK_UID = "uid://xuarrr2ab6oe"
PASSIVE_UID = "uid://didtcdc8axcrm"
ICONS = {
    "energy": ('uid://c4jtcbxdocryv', "res://assets/passives/icons/steady_growth.png"),
    "growth": ('uid://cl0u0jj7pcmpx', "res://assets/passives/icons/focused_growth.png"),
    "open": ('uid://cxwd17r4h35l5', "res://assets/passives/icons/head_start.png"),
    "empower": ('uid://c0eef6ut1vtcx', "res://assets/passives/icons/empowered_output.png"),
    "echo": ('uid://dxqkqu47g1ep5', "res://assets/passives/icons/second_wind.png"),
}

# EffectType / UnlockCondition.Type integer indexes as in the GD scripts.
E = {
    "ENERGY_OUTPUT_MULT": 0,
    "SUPPORT_RETRIGGER": 1,
    "PRODUCER_RETRIGGER": 2,
    "ENERGY_GROWTH": 3,
    "MULT_GROWTH": 4,
    "FIRST_PRODUCER_OUTPUT_MULT": 5,
    "FIRST_PRODUCER_EMPOWER": 6,
    "LAST_PRODUCER_OUTPUT_MULT": 7,
    "LAST_PRODUCER_EMPOWER": 8,
    "GOLD_CHANCE_BONUS": 9,
    "GOLD_FLAT_BONUS": 10,
    "BREAK_SAVE_CHANCE": 11,
    "ALTERNATING_OUTPUT_MULT": 12,
    "RELAY_OUTPUT_MULT": 13,
    "RELAY_EMPOWER": 14,
    "ADJACENCY_OUTPUT_MULT": 15,
    "FULL_OCCUPANCY_OUTPUT_MULT": 16,
    "ONE_TILE_OUTPUT_MULT": 17,
    "ONE_TILE_RETRIGGER": 18,
    "ONE_TILE_PERSONAL_GROWTH": 19,
    "ONE_TILE_BREAK_WARD": 20,
    "LAYOUT_SIGHTLINE": 21,
    "LAYOUT_END_RETRIGGER": 22,
    "LAYOUT_INWARD_MOMENTUM": 23,
    "LAYOUT_CLOSED_ORBIT": 24,
    "LAYOUT_COIL_CHARGE": 25,
    "LAYOUT_OUTWARD_PULSE": 26,
    "LAYOUT_DOWNSTROKE": 27,
    "LAYOUT_TURNAROUND": 28,
    "LAYOUT_COMPRESSION": 29,
    "LAYOUT_SINGULARITY": 30,
}
U = {
    "LIFETIME_TRIGGERS": 0,
    "WIN_RUN": 1,
    "GOLD_HELD": 2,
    "FULL_MAP_CARDS": 4,
    "TRIGGERS_SINGLE_TURN": 5,
    "PRODUCER_TRIGGERS": 7,
    "SUPPORT_TRIGGERS": 8,
    "PRODUCER_RETRIGGERS": 9,
    "SUPPORT_RETRIGGERS_IN_RUN": 10,
    "RUNS_COMPLETED": 11,
    "WIN_DIFFICULTY": 12,
    "GOLD_EARNED_IN_RUN": 13,
    "ENERGY_CARD_TRIGGERS_IN_RUN": 14,
    "MULT_CARD_TRIGGERS_IN_RUN": 15,
    "ENERGY_BONUS_IN_RUN": 16,
    "MULT_BONUS_IN_RUN": 17,
    "CARDS_BROKEN": 18,
    "BREAKS_PREVENTED_BY_FUSE": 19,
    "ALTERNATING_ACTIVATIONS": 20,
    "SPECTRUM_TURNS": 21,
    "SUPPORT_THEN_PRODUCER": 22,
    "SUPPORT_AFFECTED_PRODUCERS": 23,
    "ADJACENT_SAME_PRODUCT_TRIGGERS": 24,
    "ONE_TILE_ACTIVATIONS": 25,
    "ONE_TILE_BREAKS": 26,
    "ONE_TILE_SAME_CARD_TRIGGERS_IN_RUN": 27,
    "LAST_PRODUCER_TRIGGERS": 28,
    "FULL_SEGMENT_TURNS": 29,
    "RESONANT_ARRAY_FILL": 30,
    "LAYOUT_LEVEL": 31,
    "PRODUCER_RETRIGGERS_OR_TURN_TRIGGERS": 32,
    "WIN_DIFFICULTY_AND_GOLD": 33,
}


def tres(p: dict) -> str:
    icon_uid, icon_path = ICONS[p["icon"]]
    copies = p.get("copy_thresholds")
    copy_line = ""
    if copies:
        copy_line = "copy_thresholds = Array[int]([%s])\n" % ", ".join(str(x) for x in copies)
    extra_int = p.get("extra_int", 0)
    extra_float = p.get("extra_float", 0.0)
    extra_lines = ""
    if extra_int:
        extra_lines += "extra_int = %d\n" % extra_int
    if extra_float:
        extra_lines += "extra_float = %s\n" % extra_float
    starts = "starts_unlocked = true\n" if p.get("starts") else ""
    char = 'character_id = "%s"\n' % p["layout"] if p.get("layout") else ""
    uc = p["unlock"]
    extra_th = "extra_threshold = %d\n" % uc["extra"] if uc.get("extra") else ""
    diff = "difficulty_level = %d\n" % uc["diff"] if uc.get("diff") else ""
    uchar = 'character_id = "%s"\n' % uc["layout"] if uc.get("layout") else ""
    return f"""[gd_resource type="Resource" script_class="SegmentPassive" format=3]

[ext_resource type="Script" uid="{UNLOCK_UID}" path="res://scripts/resources/unlock_condition.gd" id="1_unlock_script"]
[ext_resource type="Script" uid="{PASSIVE_UID}" path="res://scripts/resources/segment_passive.gd" id="2_passive_script"]
[ext_resource type="Texture2D" uid="{icon_uid}" path="{icon_path}" id="3_icon"]

[sub_resource type="Resource" id="UnlockCondition_main"]
script = ExtResource("1_unlock_script")
condition_type = {uc["type"]}
threshold = {uc["th"]}
{extra_th}{diff}{uchar}description = "{uc["desc"]}"

[resource]
script = ExtResource("2_passive_script")
id = "{p["id"]}"
{char}display_name = "{p["name"]}"
description = "{p["desc"]}"
icon = ExtResource("3_icon")
tile_cost = {p.get("tiles", 1)}
max_copies = {p.get("max", 1)}
{copy_line}effect_type = {p["effect"]}
effect_value = {p["value"]}
{extra_lines}unlock_condition = SubResource("UnlockCondition_main")
{starts}"""


PASSIVES = [
    dict(id="energy_boost", name="Energy Boost", desc="Energy cards on this segment produce +5% Energy.", effect=E["ENERGY_OUTPUT_MULT"], value=0.05, max=3, tiles=1, copy_thresholds=[150, 1500, 5000], icon="energy", unlock=dict(type=U["LIFETIME_TRIGGERS"], th=150, desc="150 / 1,500 / 5,000 lifetime card triggers")),
    dict(id="energy_amplifier", name="Energy Amplifier", desc="Energy cards on this segment produce +10% Energy.", effect=E["ENERGY_OUTPUT_MULT"], value=0.10, max=1, tiles=2, icon="energy", unlock=dict(type=U["WIN_DIFFICULTY"], th=3, diff=3, desc="Win a run on Difficulty 3")),
    dict(id="focused_growth", name="Focused Growth", desc="Every 5th activation, an Energy card on this segment permanently gains +1 Energy for the run.", effect=E["ENERGY_GROWTH"], value=1.0, extra_int=5, max=2, tiles=1, copy_thresholds=[8, 25], icon="growth", unlock=dict(type=U["ENERGY_CARD_TRIGGERS_IN_RUN"], th=8, desc="Trigger one Energy card 8 / 25 times in a single run")),
    dict(id="accelerated_growth", name="Accelerated Growth", desc="Every 5th activation, an Energy card permanently gains +3 Energy for the run.", effect=E["ENERGY_GROWTH"], value=3.0, extra_int=5, max=1, tiles=3, icon="growth", unlock=dict(type=U["ENERGY_BONUS_IN_RUN"], th=30, desc="Get one Energy card to +30 bonus Energy in one run")),
    dict(id="ratio_step", name="Ratio Step", desc="Every 5th activation, a Mult card on this segment permanently gains +0.1 Mult for the run.", effect=E["MULT_GROWTH"], value=0.1, extra_int=5, max=2, tiles=1, copy_thresholds=[8, 25], icon="growth", unlock=dict(type=U["MULT_CARD_TRIGGERS_IN_RUN"], th=8, desc="Trigger one Mult card 8 / 25 times in a single run")),
    dict(id="ratio_cascade", name="Ratio Cascade", desc="Every 5th activation, a Mult card permanently gains +0.3 Mult for the run.", effect=E["MULT_GROWTH"], value=0.3, extra_int=5, max=1, tiles=3, icon="growth", unlock=dict(type=U["MULT_BONUS_IN_RUN"], th=15, desc="Get one Mult card to +1.5 bonus Mult in one run")),
    dict(id="second_wind", name="Second Wind", desc="Each Support activation has an independent 2% retrigger chance.", effect=E["SUPPORT_RETRIGGER"], value=0.02, max=3, tiles=1, copy_thresholds=[80, 500, 1800], icon="echo", unlock=dict(type=U["SUPPORT_TRIGGERS"], th=80, desc="80 / 500 / 1,800 lifetime Support triggers")),
    dict(id="encore_engine", name="Encore Engine", desc="Each Support activation has an independent 7% retrigger chance.", effect=E["SUPPORT_RETRIGGER"], value=0.07, max=1, tiles=2, icon="echo", unlock=dict(type=U["SUPPORT_RETRIGGERS_IN_RUN"], th=20, desc="Cause 20 Support retriggers in one run")),
    dict(id="spark", name="Spark", desc="Each Producer activation has an independent 2% retrigger chance.", effect=E["PRODUCER_RETRIGGER"], value=0.02, max=3, tiles=1, copy_thresholds=[0, 1000, 3500], starts=True, icon="echo", unlock=dict(type=U["PRODUCER_TRIGGERS"], th=0, desc="1,000 / 3,500 lifetime Producer triggers for extra copies")),
    dict(id="spark_storm", name="Spark Surge", desc="Each Producer activation has an independent 7% retrigger chance.", effect=E["PRODUCER_RETRIGGER"], value=0.07, max=1, tiles=2, icon="echo", unlock=dict(type=U["PRODUCER_RETRIGGERS_OR_TURN_TRIGGERS"], th=40, extra=50, desc="40 Producer retriggers, or 50 card triggers in one turn")),
    dict(id="head_start", name="Head Start", desc="The first Producer activated on this segment each turn gains +15% output.", effect=E["FIRST_PRODUCER_OUTPUT_MULT"], value=0.15, max=2, tiles=1, copy_thresholds=[2, 10], icon="open", unlock=dict(type=U["RUNS_COMPLETED"], th=2, desc="Complete 2 / 10 runs")),
    dict(id="empowered_output", name="Empowered Output", desc="The first Producer activated on this segment each turn is Empowered.", effect=E["FIRST_PRODUCER_EMPOWER"], value=1.0, max=1, tiles=3, icon="empower", unlock=dict(type=U["WIN_DIFFICULTY"], th=5, diff=5, desc="Win a run on Difficulty 5")),
    dict(id="last_word", name="Last Word", desc="The last Producer activated on this segment each turn gains +15% output.", effect=E["LAST_PRODUCER_OUTPUT_MULT"], value=0.15, max=2, tiles=1, copy_thresholds=[200, 1200], icon="open", unlock=dict(type=U["LAST_PRODUCER_TRIGGERS"], th=200, desc="200 / 1,200 last-Producer activations")),
    dict(id="final_flourish", name="Final Flourish", desc="The last Producer activated on this segment each turn is Empowered.", effect=E["LAST_PRODUCER_EMPOWER"], value=1.0, max=1, tiles=3, icon="empower", unlock=dict(type=U["WIN_DIFFICULTY"], th=4, diff=4, desc="Win a run on Difficulty 4")),
    dict(id="gilded_contact", name="Gilded Contact", desc="Gold cards have an independent 25% chance to produce +1 Gold.", effect=E["GOLD_CHANCE_BONUS"], value=0.25, extra_int=1, max=2, tiles=1, copy_thresholds=[20, 25], icon="open", unlock=dict(type=U["GOLD_EARNED_IN_RUN"], th=20, extra=25, desc="Earn 20 gold in one run, then hold 25 gold at once")),
    dict(id="minting_press", name="Minting Press", desc="Gold cards always produce +1 Gold.", effect=E["GOLD_FLAT_BONUS"], value=1.0, extra_int=1, max=1, tiles=3, icon="empower", unlock=dict(type=U["WIN_DIFFICULTY_AND_GOLD"], th=4, diff=4, desc="Win on Difficulty 4 while holding at least 40 Gold")),
    dict(id="safety_fuse", name="Safety Fuse", desc="A card that would break has an independent 20% chance to ignore the break.", effect=E["BREAK_SAVE_CHANCE"], value=0.20, max=2, tiles=1, copy_thresholds=[5, 20], icon="echo", unlock=dict(type=U["CARDS_BROKEN"], th=5, desc="Lose 5 / 20 cards to break effects")),
    dict(id="aegis_matrix", name="Aegis Matrix", desc="A card that would break has a 50% chance to ignore the break.", effect=E["BREAK_SAVE_CHANCE"], value=0.50, max=1, tiles=3, icon="empower", unlock=dict(type=U["BREAKS_PREVENTED_BY_FUSE"], th=20, desc="Prevent 20 breaks while Safety Fuse is placed")),
    dict(id="alternating_current", name="Alternating Current", desc="An Energy, Mult, or Gold card gains +10% output when the preceding numeric card produced a different resource.", effect=E["ALTERNATING_OUTPUT_MULT"], value=0.10, max=2, tiles=1, copy_thresholds=[40, 200], icon="energy", unlock=dict(type=U["ALTERNATING_ACTIVATIONS"], th=40, desc="40 / 200 alternating-resource activations")),
    dict(id="spectrum_engine", name="Spectrum Engine", desc="Same alternating-resource condition grants +25% output.", effect=E["ALTERNATING_OUTPUT_MULT"], value=0.25, max=1, tiles=2, icon="energy", unlock=dict(type=U["SPECTRUM_TURNS"], th=8, desc="Activate Energy, Mult, and Gold on one segment in the same turn, 8 times")),
    dict(id="relay_capacitor", name="Relay Capacitor", desc="After a Support activates, the next Producer gains +15% output. Each copy holds one charge.", effect=E["RELAY_OUTPUT_MULT"], value=0.15, max=2, tiles=1, copy_thresholds=[40, 200], icon="echo", unlock=dict(type=U["SUPPORT_THEN_PRODUCER"], th=40, desc="Complete 40 / 200 Support-then-Producer sequences")),
    dict(id="conductor_core", name="Conductor Core", desc="The first Support activated on this segment each turn Empowers the next Producer.", effect=E["RELAY_EMPOWER"], value=1.0, max=1, tiles=3, icon="empower", unlock=dict(type=U["SUPPORT_AFFECTED_PRODUCERS"], th=200, desc="Have Support effects trigger or Empower 200 Producers")),
    dict(id="resonant_pair", name="Resonant Pair", desc="A Producer adjacent to another Producer of the same product gains +10% output.", effect=E["ADJACENCY_OUTPUT_MULT"], value=0.10, extra_int=1, max=2, tiles=1, copy_thresholds=[80, 400], icon="energy", unlock=dict(type=U["ADJACENT_SAME_PRODUCT_TRIGGERS"], th=80, desc="Trigger qualifying adjacent Producers 80 / 400 times")),
    dict(id="resonant_array", name="Resonant Array", desc="A Producer with at least two adjacent Producers of the same product gains +25% output.", effect=E["ADJACENCY_OUTPUT_MULT"], value=0.25, extra_int=2, max=1, tiles=2, icon="energy", unlock=dict(type=U["RESONANT_ARRAY_FILL"], th=1, desc="Fill a segment of at least six tiles with one Producer product and complete a turn")),
    dict(id="packed_line", name="Packed Line", desc="If every tile in this segment is occupied, Producers gain +8% output.", effect=E["FULL_OCCUPANCY_OUTPUT_MULT"], value=0.08, max=2, tiles=1, copy_thresholds=[8, 25], icon="open", unlock=dict(type=U["FULL_SEGMENT_TURNS"], th=8, desc="Complete 8 / 25 turns with at least one fully occupied segment")),
    dict(id="saturated_field", name="Saturated Field", desc="If every tile in this segment is occupied, Producers gain +20% output.", effect=E["FULL_OCCUPANCY_OUTPUT_MULT"], value=0.20, max=1, tiles=2, icon="empower", unlock=dict(type=U["FULL_MAP_CARDS"], th=1, desc="Fill the entire map with cards and complete a turn")),
    dict(id="solo_dynamo", name="Solo Dynamo", desc="On a one-tile segment, that card's Energy, Mult, or Gold output +30%.", effect=E["ONE_TILE_OUTPUT_MULT"], value=0.30, max=1, tiles=1, icon="energy", unlock=dict(type=U["ONE_TILE_ACTIVATIONS"], th=80, desc="80 activations on one-tile segments")),
    dict(id="echo_chamber", name="Echo Chamber", desc="On a one-tile segment, every activation has an independent 10% chance to retrigger.", effect=E["ONE_TILE_RETRIGGER"], value=0.10, max=1, tiles=1, icon="echo", unlock=dict(type=U["ONE_TILE_ACTIVATIONS"], th=400, desc="400 activations on one-tile segments")),
    dict(id="growth_capsule", name="Growth Capsule", desc="On a one-tile segment, every 3rd activation gives the card +5% personal output for the run, capped at +30%.", effect=E["ONE_TILE_PERSONAL_GROWTH"], value=0.05, extra_int=3, extra_float=0.30, max=1, tiles=1, icon="growth", unlock=dict(type=U["ONE_TILE_SAME_CARD_TRIGGERS_IN_RUN"], th=15, desc="Trigger the same card 15 times in one run on a one-tile segment")),
    dict(id="anchor_ward", name="Anchor Ward", desc="On a one-tile segment, the first time each turn that card would break, the break is prevented.", effect=E["ONE_TILE_BREAK_WARD"], value=1.0, max=1, tiles=1, icon="echo", unlock=dict(type=U["ONE_TILE_BREAKS"], th=8, desc="Lose 8 cards to break effects on one-tile segments")),
    dict(id="sightline_calibration", name="Sightline Calibration", desc="A Producer gains +5% output for each occupied card activated earlier in its row, capped at +25% per copy.", effect=E["LAYOUT_SIGHTLINE"], value=0.05, extra_float=0.25, max=2, tiles=1, copy_thresholds=[3, 6], layout="surveyor", icon="energy", unlock=dict(type=U["LAYOUT_LEVEL"], th=3, layout="surveyor", desc="The Surveyor levels 3 / 6")),
    dict(id="end_of_the_line", name="End of the Line", desc="If every earlier occupied card in the row activated, its final Producer retriggers once. Once per turn.", effect=E["LAYOUT_END_RETRIGGER"], value=1.0, max=1, tiles=3, layout="surveyor", icon="empower", unlock=dict(type=U["LAYOUT_LEVEL"], th=9, layout="surveyor", desc="The Surveyor level 9")),
    dict(id="inward_momentum", name="Inward Momentum", desc="The first Producer in a ring gains +5% output per occupied card in the immediately outer ring, capped at +30% per copy.", effect=E["LAYOUT_INWARD_MOMENTUM"], value=0.05, extra_float=0.30, max=2, tiles=1, copy_thresholds=[3, 6], layout="encircler", icon="energy", unlock=dict(type=U["LAYOUT_LEVEL"], th=3, layout="encircler", desc="The Encircler levels 3 / 6")),
    dict(id="closed_orbit", name="Closed Orbit", desc="After every active card in a ring of at least 6 resolves, Energy cards in that ring permanently gain +1 Energy. Once per qualifying ring per turn.", effect=E["LAYOUT_CLOSED_ORBIT"], value=1.0, max=1, tiles=3, layout="encircler", icon="growth", unlock=dict(type=U["LAYOUT_LEVEL"], th=9, layout="encircler", desc="The Encircler level 9")),
    dict(id="coil_charge", name="Coil Charge", desc="A Producer gains +3% output per card activated earlier this turn, capped at +30% per copy.", effect=E["LAYOUT_COIL_CHARGE"], value=0.03, extra_float=0.30, max=2, tiles=1, copy_thresholds=[3, 6], layout="spiralist", icon="energy", unlock=dict(type=U["LAYOUT_LEVEL"], th=3, layout="spiralist", desc="The Spiralist levels 3 / 6")),
    dict(id="outward_pulse", name="Outward Pulse", desc="After the immediately inner ring resolves, the first Producer in this ring is Empowered. Once per turn.", effect=E["LAYOUT_OUTWARD_PULSE"], value=1.0, max=1, tiles=3, layout="spiralist", icon="empower", unlock=dict(type=U["LAYOUT_LEVEL"], th=9, layout="spiralist", desc="The Spiralist level 9")),
    dict(id="downstroke", name="Downstroke", desc="A Producer gains +5% output per consecutive occupied card immediately before it in its column, capped at +25% per copy.", effect=E["LAYOUT_DOWNSTROKE"], value=0.05, extra_float=0.25, max=2, tiles=1, copy_thresholds=[3, 6], layout="columnist", icon="energy", unlock=dict(type=U["LAYOUT_LEVEL"], th=3, layout="columnist", desc="The Columnist levels 3 / 6")),
    dict(id="turnaround", name="Turnaround", desc="When the final active card in the column resolves, it Empowers the first active Producer in the next column. Once per turn.", effect=E["LAYOUT_TURNAROUND"], value=1.0, max=1, tiles=3, layout="columnist", icon="empower", unlock=dict(type=U["LAYOUT_LEVEL"], th=9, layout="columnist", desc="The Columnist level 9")),
    dict(id="compression_gain", name="Compression Gain", desc="A Producer gains +5% output for each outer segment fully resolved earlier this turn, capped at +30% per copy.", effect=E["LAYOUT_COMPRESSION"], value=0.05, extra_float=0.30, max=2, tiles=1, copy_thresholds=[3, 6], layout="converger", icon="energy", unlock=dict(type=U["LAYOUT_LEVEL"], th=3, layout="converger", desc="The Converger levels 3 / 6")),
    dict(id="singularity", name="Singularity", desc="Center-only: that card is Empowered, ignores break during that activation, and retriggers once per turn.", effect=E["LAYOUT_SINGULARITY"], value=1.0, max=1, tiles=1, layout="converger", icon="empower", unlock=dict(type=U["LAYOUT_LEVEL"], th=9, layout="converger", desc="The Converger level 9")),
]


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    keep = set()
    for p in PASSIVES:
        text = tres(p)
        path = ROOT / f"{p['id']}.tres"
        path.write_text(text.replace("\n\n\n", "\n").rstrip() + "\n", encoding="utf-8")
        keep.add(path.name)
        print("wrote", path.name)
    for existing in ROOT.glob("*.tres"):
        if existing.name not in keep:
            existing.unlink()
            print("removed", existing.name)


if __name__ == "__main__":
    main()
