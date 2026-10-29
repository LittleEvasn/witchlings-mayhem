extends RefCounted
## Our tuning, inspired by timed survivor waves; not extracted game constants.
## Six one-minute phases repeat with chapter-specific density and species pools.
const TARGETS := [10,18,30,24,16,42]
const INTERVALS := [1.2,.9,.65,1.0,1.5,.65]
const CHAPTER_SCALE := [1.0,1.8,3.0,4.4,6.0]
const EVENTS := [
	{"at":60.0,"type":"elite"}, {"at":90.0,"type":"crossing"},
	{"at":120.0,"type":"ring"}, {"at":180.0,"type":"elite"},
	{"at":240.0,"type":"crossing"}, {"at":300.0,"type":"elite"}
]
static func phase(seconds: float) -> int: return clampi(int(fmod(maxf(0,seconds),360.0)/60),0,5)
static func chapter(seconds: float) -> int: return clampi(int(seconds/360),0,4)
static func target(seconds: float) -> int:
	return mini(280,roundi(TARGETS[phase(seconds)]*CHAPTER_SCALE[chapter(seconds)]))
static func interval(seconds: float) -> float:
	return INTERVALS[phase(seconds)]/sqrt(CHAPTER_SCALE[chapter(seconds)])
static func batch(seconds: float) -> int: return 1+chapter(seconds)
