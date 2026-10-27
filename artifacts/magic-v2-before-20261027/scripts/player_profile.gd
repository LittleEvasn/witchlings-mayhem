extends RefCounted
## Only settings and concluded experiment records persist. No permanent combat bonuses.
const PATH := "user://profile-v1.json"
var path := PATH
var data := {"version":1,"wins":0,"losses":0,"lumi_clue":false,"best_combat":0.0,"records":[],"sound":true,"music":false}
var warning := ""
func _init(save_path := PATH) -> void:
	path = save_path
func load_profile() -> void:
	if not FileAccess.file_exists(path): return
	var parsed: Variant = _read_json(path)
	if not _valid(parsed):
		parsed = _read_json(path+".bak") if FileAccess.file_exists(path+".bak") else null
		warning = "기록 파일을 읽지 못해 이전 기록 또는 기본값으로 열었어."
	if _valid(parsed):
		for key in data:
			if parsed.has(key): data[key] = parsed[key]
func _read_json(file_path: String) -> Variant:
	var parser:=JSON.new()
	return parser.data if parser.parse(FileAccess.get_file_as_string(file_path))==OK else null
func _valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version",0)!=1: return false
	if not value.get("records",[]) is Array: return false
	if value.get("records",[]).size()>10: return false
	for record in value.get("records",[]):
		if not record is Dictionary: return false
		if typeof(record.get("won",null))!=TYPE_BOOL or typeof(record.get("kit",null))!=TYPE_STRING: return false
		for field in ["combat","preparation","kills","earned","wave"]:
			var amount: Variant=record.get(field,0)
			if typeof(amount) not in [TYPE_INT,TYPE_FLOAT] or amount<0 or not is_finite(float(amount)): return false
	for key in ["wins","losses","best_combat"]:
		if typeof(value.get(key,0)) not in [TYPE_INT,TYPE_FLOAT] or value.get(key,0)<0 or not is_finite(float(value.get(key,0))): return false
	for key in ["sound","music","lumi_clue"]:
		if typeof(value.get(key,false))!=TYPE_BOOL: return false
	return true
func save_profile() -> bool:
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:
		warning="기록을 저장하지 못했어. 이번 플레이는 계속할 수 있어."
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	# Preserve the last valid file. Never replace a healthy backup with a corrupt primary.
	if FileAccess.file_exists(path) and _valid(_read_json(path)):
		DirAccess.copy_absolute(path,path+".bak")
	var error := DirAccess.rename_absolute(path+".tmp",path)
	if error!=OK: warning="기록 교체에 실패했어. 이전 기록은 남아 있어."
	return error==OK
func record_run(record: Dictionary) -> void:
	var won: bool=record.won
	data["wins" if won else "losses"] += 1
	if won:
		data.lumi_clue=true
		if data.best_combat<=0 or record.combat<data.best_combat: data.best_combat=record.combat
	data.records.push_front(record.duplicate(true))
	data.records.resize(mini(10,data.records.size()))
