extends RefCounted

var _failures: Array[String] = []
var _passes: int = 0
var _summary_done: bool = false
var _summary_code: int = 0

func check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("[test][PASS] %s" % label)
	else:
		_failures.append(label)
		print("[test][FAIL] %s" % label)
		push_error("[test][FAIL] %s" % label)

func has_failures() -> bool:
	return not _failures.is_empty()

func failure_count() -> int:
	return _failures.size()

func pass_count() -> int:
	return _passes

func is_summary_done() -> bool:
	return _summary_done

func summary_once() -> int:
	if _summary_done:
		return _summary_code
	_summary_done = true
	if _failures.is_empty():
		print("[test] SUMMARY PASS (%d checks)" % _passes)
		_summary_code = 0
	else:
		print("[test] SUMMARY FAIL %d/%d: %s" % [_failures.size(), _passes + _failures.size(), ", ".join(_failures)])
		_summary_code = 1
	return _summary_code
