class_name Save
extends RefCounted
## 存档 user://save.cfg：每关一个小节，记最好评级，以及上次走到的房间（连同那时的分数）。
## 自动测试时 enabled = false，不碰玩家的存档。

const PATH := "user://save.cfg"

static var enabled := true


static func _load() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # 第一次玩时文件不存在，就是空的
	return cfg


static func best(level_id: String) -> String:
	return _load().get_value(level_id, "best", "")


## 上次走到的房间：{room, score}；没有存档（或已经通关清掉了）就返回 {}
static func checkpoint(level_id: String) -> Dictionary:
	var cfg := _load()
	if not cfg.has_section_key(level_id, "room"):
		return {}
	return {room = cfg.get_value(level_id, "room"), score = cfg.get_value(level_id, "score", {})}


static func store_checkpoint(level_id: String, room: int, score: Dictionary) -> void:
	if not enabled:
		return
	var cfg := _load()
	cfg.set_value(level_id, "room", room)
	cfg.set_value(level_id, "score", score)
	cfg.save(PATH)


## 送达：清掉房间存档；完整通关并且比以前好，就记下新的最好评级
static func finish(level_id: String, grade: String, full_run: bool) -> bool:
	if not enabled:
		return false
	var cfg := _load()
	if cfg.has_section_key(level_id, "room"):
		cfg.erase_section_key(level_id, "room")
		cfg.erase_section_key(level_id, "score")
	var improved := full_run and Score.better(grade, cfg.get_value(level_id, "best", ""))
	if improved:
		cfg.set_value(level_id, "best", grade)
	cfg.save(PATH)
	return improved
