# Magic60 진단 하네스 · 2026-10-30

제품 코드를 수정하지 않고 실제 Godot 실행에서 측정한 진단 스크립트다. JSON을 출력하는 probe에는 자동 PASS/FAIL assert가 없는 항목도 있다. 종료 코드0을 정상 마법으로 해석하지 말고 보고서의 관측값과 결함 분류를 함께 볼 것.

실행: `Godot_v4.6.2-stable_win64.exe --headless --path . --quit-after 120000 --script res://tests/magic60_audit/<name>.gd`. 실행 전 artifacts 폴더를 만든다. 기존 baseline은 `python tools/run_tests.py magic60_test`, `python tools/run_tests.py connector_scope_test`. 테스트는 record_runs=false와 별도 메모리 프로필로 사용자 진행 저장을 피한다.

- 빠른 재현: orbit_variant_probe, p1_p2_probe, named_edge_probes, unresolved_edge_probe, fall_path_probe, dual_event_damage_probe, cap_saturation_probe, thorn_tail_probe (각 파일 접두 magic60_).
- 라이브 대형: attack_modifier_lifecycle(1440×600 frame), connector_injection(5184 조합/6480 사건).
- 부하: four_orb_stress(9배치/300적), stress_batch2_repeat(동일 최악 조합2회; 이 파일이 있는 경우). CPU 시간이며 렌더 FPS가 아니다.
- 컴파일: compile_supplement는 올바른 기본/합성 강화 입력을 사용한다. compile_matrix는 최초 pilot 원문을 보존했다. **pilot 전체 invalid 판정을 제품 결함으로 쓰지 말 것.** pilot _token은 합성에 불가능한 @3을 붙일 수 있다. 746496 3단 체인과5184 연결의 기본 입력은 유효하며 해당 결과만 최종 집계에 사용했다. 최신 유효 입력 쌍/보조/중첩/8칸 결과는 supplement JSON에서 가져온다. pilot은 자동 정기 검사 대상으로 사용하지 않는다.

보고서: docs/MAGIC60-FIX-AND-TEST-REPORT.md. 검증 JSON: docs/verification/magic60-20261030/magic60-full-verification.json. 835520개는 수정된 유효 컴파일 범주의 합이며 원시 실행 횟수나 전투 성공 횟수가 아니다.
