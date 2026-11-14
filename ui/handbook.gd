extends Control
## The handbook: a stand-in with the API of design/plans/mission-1-contracts.md, until lane H's screen replaces it.

signal closed

var _unlocked: Array[String] = []
var _learned: Array[String] = []
var _page := ""


func unlock(id: String) -> bool:
	if id in _unlocked:
		return false
	_unlocked.append(id)
	return true


func learned(ids: Array) -> void:
	for id: String in ids:
		if id not in _learned:
			_learned.append(id)


func open(page := "") -> void:
	_page = page
	show()


func close() -> void:
	hide()
	closed.emit()


func title(id: String) -> String:
	return id


func log_decision(_title: String, _choice: String) -> void:
	pass


func unread() -> int:
	return 0


func state() -> Dictionary:
	return {"open": visible, "tab": "", "page": _page, "unlocked": _unlocked, "learned": _learned, "total": 23}
