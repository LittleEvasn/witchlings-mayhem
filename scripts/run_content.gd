extends RefCounted
## The Lumi route. Combat excludes preparation/trial; personal combat editing stays live.
const VERSION := "lumi-magic-v2"
const CHAPTERS := [
	{"title":"숙제를 대신해 줄 마법", "goal":"실패작을 물리치고 첫 제작 재료 모으기", "duration":60.0,"budget":48,
		"lumi":"숙제만 부탁했는데… 왜 나한테 달려오는 거야?", "craft":"오브 2에도 공격을 넣어볼까? 새 구체는 직접 지정 제작할 수도 있어."},
	{"title":"멈추지 않는 주문", "goal":"무리를 헤치며 두 오브의 조합 키우기", "duration":75.0,"budget":64,
		"lumi":"좋아. 실패작의 마석이면 우리 주문도 고칠 수 있겠어.", "craft":"자주 쓰는 공격이나 보조를 강화해보자. 같은 구체를 붙이거나 마석으로 +1."},
	{"title":"빠뜨린 안전장치", "goal":"돌진을 피하고 주력 조합 완성하기", "duration":90.0,"budget":78,
		"lumi":"아. ‘더 좋은 주문을 만들어’라고만 했네. 멈추라는 말은…", "craft":"다음은 완성한 주문을 써볼 차례야. 서로 다른 두 +3 공격은 합성 도감도 확인해봐."},
	{"title":"이번 주문은 우리 편", "goal":"완성한 조합으로 혼성 무리 돌파하기", "duration":105.0,"budget":90,
		"lumi":"이번에는 우리가 만든 주문으로 끝내자!", "craft":"마지막 준비야. 체력을 확인하고, 시험 발사로 두 오브가 함께 작동하는지 보자."},
	{"title":"끝없는 모범답안", "goal":"폭주한 마법 조수를 쓰러뜨리기", "duration":150.0,"target_seconds":120.0,"budget":24,
		"lumi":"완벽한 숙제보다, 지금 멈추는 게 먼저야!", "craft":""}
]
const INTRO := [
	"숙제를 대신할 마법 조수. 원래 계획은 그게 전부였다.",
	"루미가 빼먹은 건 딱 한 줄. ‘이만하면 됐어. 이제 멈춰.’",
	"실패작의 마석으로 주문을 다시 만들자. 교수님이 돌아오기 전에!"
]
static func chapter(number: int) -> Dictionary:
	return CHAPTERS[clampi(number-1,0,CHAPTERS.size()-1)]
static func combat_limit() -> float:
	var total := 0.0
	for c in CHAPTERS: total += c.duration
	return total
static func clock(seconds: float) -> String:
	return "%02d:%02d" % [floori(seconds/60.0),int(seconds)%60]
