class_name Progression
extends RefCounted
## What the trail skins cost, and the rules for earning them.
##
## The brief came with a paper on how games create dependency. It names the
## mechanisms that do it hardest: unpredictable rewards, daily login streaks,
## timed events you lose by not showing up, content with no end. None of those
## are here, and that is deliberate - they work by making the player anxious
## about not playing, which is the thing the paper is warning about.
##
## What is here is the part of the same paper that describes earned progress
## and mastery: a short, finite list of goals that are stated up front, each
## one tied to something the player actually did. Every skin can be earned by
## racing, nothing expires, nothing is random, and the list ends.

## skin index -> { key, label }. Index 0 is the stock white trail and is
## always available, so it is not listed.
const RULES := [
	{"skin": 1, "key": "finish", "label": "Bir yarışı bitir"},
	{"skin": 2, "key": "podium", "label": "İlk üçe gir"},
	{"skin": 3, "key": "win", "label": "Bir yarış kazan"},
	{"skin": 4, "key": "bronze", "label": "BRONZ madalya al"},
	{"skin": 5, "key": "silver", "label": "GÜMÜŞ madalya al"},
	{"skin": 6, "key": "gold", "label": "ALTIN madalya al"},
	{"skin": 7, "key": "both_maps", "label": "Her iki haritayı da kazan"},
	{"skin": 8, "key": "author", "label": "AUTHOR süresini geç"},
]

const MEDAL_KEYS := {
	"BRONZE": "bronze",
	"SILVER": "silver",
	"GOLD": "gold",
	"AUTHOR": "author",
}

static func rule_for(skin: int) -> Dictionary:
	for r in RULES:
		if int(r["skin"]) == skin:
			return r
	return {}

## What the player has to do to get this skin, or "" when it is free.
static func requirement(skin: int) -> String:
	var r := rule_for(skin)
	return str(r["label"]) if r.has("label") else ""

## Which achievement keys a finished race is worth.
##
## Medals stack downward on purpose: an AUTHOR lap also counts as gold, silver
## and bronze, so a strong player is never left staring at an earlier reward
## they skipped past.
static func keys_earned(place: int, medal: String, won_maps: Array) -> PackedStringArray:
	var out := PackedStringArray(["finish"])
	if place <= 3:
		out.append("podium")
	if place == 1:
		out.append("win")
	var ladder := ["BRONZE", "SILVER", "GOLD", "AUTHOR"]
	var reached := ladder.find(medal)
	for i in range(reached + 1):
		out.append(str(MEDAL_KEYS[ladder[i]]))
	if won_maps.size() >= TrackGen.track_count():
		out.append("both_maps")
	return out

## Skins unlocked by a set of achievement keys.
static func skins_for(keys: PackedStringArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	for r in RULES:
		if keys.has(str(r["key"])):
			out.append(int(r["skin"]))
	return out
