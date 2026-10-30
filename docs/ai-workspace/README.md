# AI 협업 보고서 공간

이 디렉터리는 서로 다른 ChatGPT 채팅과 Codex가 GitHub 문서로 분석·검토·결정·작업 인계를 주고받는 공용 공간이다. 실시간 회의나 자동 알림을 제공하는 것은 아니다.

## 폴더
- `INDEX.md`: 활성 보고서와 상태를 찾는 목록
- `AGENTS.md`: 이 폴더용 AI 작업 규칙
- `reports/`: 조사 결과와 수정 제안
- `discussions/`: 의견, 독립 검토, 반론
- `decisions/`: 사용자 승인 사항
- `handoffs/`: Codex 구현·검증 인계
- `archive/`: 실제 작업 완료와 검증을 거친 기록

## 작업 방식
1. 처음 방문한 GPT/Codex는 `AGENTS.md` 및 `INDEX.md`를 읽는다.
2. 모든 제안은 `PROPOSED` 상태로 시작한다. 보고서는 곧바로 코드 변경 지시가 아니다.
3. 서로 다른 GPT의 의견은 원문을 덮어쓰지 않고 `discussions/`에 근거를 남긴다.
4. 확정된 사용자 결정만 `decisions/`로 구별한다.
5. Codex는 실제 코드 반영·테스트 근거·커밋을 확인한 뒤에만 완료 보고서를 `archive/`로 옮기고 `INDEX.md`를 갱신한다.
6. GitHub Actions 자동 보관은 아직 설치하지 않았다. 작업자가 수행할 때만 정리된다.

상위 `AGENTS.md`와 최신 사용자 지시가 최우선이다.
