class_name DailyTask
extends RefCounted

const GARDEN_CARE:    int = 0
const HARVEST:        int = 1
const FOCUS_SESSION:  int = 2
const ONLINE_TIME:    int = 3

const DAILY:  int = 0
const WEEKLY: int = 1

# String → int lookup for BE string enums
const _TYPE_MAP: Dictionary = {
	"GARDEN_CARE":   0,
	"HARVEST":       1,
	"FOCUS_SESSION": 2,
	"ONLINE_TIME":   3,
}
const _CYCLE_MAP: Dictionary = {
	"DAILY":  0,
	"WEEKLY": 1,
}

var id:               String = ""
var title:            String = ""
var description:      String = ""
var type:             int    = GARDEN_CARE
var action_subtype:   String = ""  # "water" | "fertilize" | "pesticide" | ""
var target:           int    = 1
var cycle:            int    = DAILY
var reward_currency:  int    = 0
var reward_item_id:   String = ""
var reward_item_qty:  int    = 0
var reward_xp:        int    = 0

static func from_dict(d: Dictionary) -> DailyTask:
	var t := DailyTask.new()
	t.id             = str(d.get("id", ""))
	t.title          = str(d.get("title", ""))
	t.description    = str(d.get("description", ""))
	t.action_subtype = str(d.get("actionSubtype", "")).to_lower()
	t.target         = int(d.get("target", 1))
	t.reward_currency = int(d.get("rewardCurrency", 0))
	t.reward_item_id  = str(d.get("rewardItemId", ""))
	t.reward_item_qty = int(d.get("rewardItemQty", 0))
	t.reward_xp       = int(d.get("rewardXp", 0))

	var raw_type: Variant = d.get("type", 0)
	if raw_type is String:
		t.type = _TYPE_MAP.get(raw_type.to_upper(), GARDEN_CARE)
	else:
		t.type = int(raw_type)

	var raw_cycle: Variant = d.get("cycle", 0)
	if raw_cycle is String:
		t.cycle = _CYCLE_MAP.get(raw_cycle.to_upper(), DAILY)
	else:
		t.cycle = int(raw_cycle)

	return t
