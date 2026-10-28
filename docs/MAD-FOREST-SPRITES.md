# 광기의 숲에 필요한 적 외형 수

조사 기준: SurvivatonsAndMore/VampireSurvivorsFiles의 v1.16.111 추출본.
일반적인 FOREST 시간표의 enemies/bosses 및 무리 이벤트에서 참조하는 적의 textureName + frameNames를 중복 제거했다.

| 외형 묶음 | 변형 그림 수 |
|---|---:|
| 작은 박쥐 Bat1~5 |5|
| 큰 박쥐 XLBat |1|
| 좀비 Ghoul1~3 |3|
| 해골 Skeleton1~6 |6|
| 유령 Ghost |1|
| 머드맨 Mudman1~2 |2|
| 늑대인간 Werewolf1 |1|
| 큰 사마귀 XLMantis |1|
| 큰 미라 XLMummy |1|
| 꽃 Flower1~2 |2|
| 큰 꽃 XLFlower1 |1|
| 마지막 사신 XLReaper |1|
| **합계** |**25**|

- 일반 출현16ID의 프레임 키는24개. 보스로만 추가되는 새 그림은 사신1개. 중간 보스/박쥐떼/유령떼/꽃벽은 이미 센 그림을 재사용한다.
- 이는 애니메이션의 낱장 수가 아닌 서로 다른 첫 스프라이트 이름/영역 수다. idleFrameCount 같은 걷기 프레임은 더하지 않았다.
- 이 묶음 분류로는 기본 디자인11개+사신1개에 변형을 붙인 구조다. 데이터 이름으로 분류한 것이며 PNG 픽셀을 대조한 색상변경/별도작화 판정은 아니다.
- Ghost2는 도감의 변형 관계에 있지만 이번 FOREST 기본 출현 목록에 없어 제외했다. 특수 해금 이벤트/모드까지 포함한 모든 가능한 출현을 뜻하지 않는다.
- 사신은 원작의30분 종료 처리다. 우리 최종보스를 반드시 사신처럼 만들 필요는 없다.

출처:
- https://github.com/SurvivatonsAndMore/VampireSurvivorsFiles/blob/main/Game%20Version.txt
- https://github.com/SurvivatonsAndMore/VampireSurvivorsFiles/blob/main/Data/Vampire%20Survivors/Stage.json
- https://github.com/SurvivatonsAndMore/VampireSurvivorsFiles/blob/main/Data/Vampire%20Survivors/Enemy.json

조사보조 최초 보고의26개는 재집계에서 정정했다. 최종 값은 literal union24+사신1=25이며, 비출현 Ghost2를 더하지 않는다.
