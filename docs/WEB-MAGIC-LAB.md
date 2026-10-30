# 마법 60종 웹 실험실 — Godot 웹 빌드

## 개요
기존 Godot 4.6.2 훈련장(`scenes/training.tscn`, `scripts/training_game.gd`, `scripts/training_room.gd`)을 **동일한 마법 로직과 에셋**으로 브라우저에서 실행한다. JavaScript로 별도 모의 구현하지 않는다.

기본 30종 + 합성 30종, 기본 강화 0~3, 4오브 × 8칸, 고정 무적 표적 4명, 편집 즉시 발사 및 피해/명중 집계. 웹판은 훈련장에서 시작하고 Esc/타이틀 버튼은 기존 게임의 타이틀로 돌아간다.

## 원본 보존
- `project.godot`과 `scenes/main.tscn`은 **건드리지 않는다**.
- `tools/build_web_lab.py`가 마법/씬/아트 리소스를 **임시 복사**해 그 복사본에서만 시작 장면을 `training.tscn`으로 바꾼다.
- 편집기 전용 `addons/godot_ai` 자동 로드와 편집기 플러그인 등록만 임시 프로젝트에서 제거한다.
- 기존 Windows `Windows Lumi` export preset은 보존하고 웹 프리셋 `Web Magic Lab`을 추가한다.
- 공식 Godot 4.6.2 Web 내보내기 (WebAssembly + WebGL2/Compatibility, single-thread) 사용.
- 이번 작업에서는 기존 60종 마법/밸런스/버그 로직을 변경하지 않는다.

## GitHub Actions 자동 생성
`.github/workflows/web-magic-lab.yml`은 main의 관련 파일 수정 또는 Actions의 수동 실행으로 시작하도록 설정됐다.

1. Linux용 공식 Godot 4.6.2와 동일 버전 웹 export templates 설치.
2. `tools/web_lab_static_test.py` 테스트.
3. Godot 임포트, 훈련장 실제 엔진 **headless 60프레임 부팅**, WebAssembly 내보내기.
4. `index.html`, `index.js`, `index.wasm`, `index.pck` 존재 확인.
5. Actions Artifact `witchlings-web-magic-lab` 업로드.
6. GitHub Pages 배포 시도.

워크플로가 실제 성공했다는 로그가 확인되기 전에는 웹 빌드가 완료되었다고 보고하지 않는다. Pages가 활성화되어 있다면 **배포 후** 웹 접속 주소는 `https://littleevasn.github.io/witchlings-mayhem/`이다. 확인 전에는 정상 작동을 보장할 수 없다.

## 로컬 실행 방법
Godot 4.6.2 에디터와 그 버전의 export templates 설치 후:

```sh
python -m unittest discover -s tools -p web_lab_static_test.py -v
python tools/build_web_lab.py --godot godot --output artifacts/web-lab
python -m http.server 8000 --directory artifacts/web-lab
```

브라우저에서 `http://localhost:8000/`에 접속한다. `file://`로 직접 열지 않는다. Windows에서 실행할 경우 `--godot`에 Godot 실행파일 전체 경로를 지정해도 된다.

## 배포 상태별 판정
- 소스/설정 업로드: **빌드 준비**만 끝난 상태
- GitHub Actions `build` 성공: Godot 웹 파일 생성 및 헤드리스 부팅 확인
- `deploy` 성공: GitHub Pages에 파일 게시됨
- 실제 브라우저 수동 검수: WebGL 렌더·마우스 편집·발사·피해 집계 확인
- 성능/밸런스/전체60 조합 품질: 독립적인 실측이 필요

Pages 작업이 막히면 GitHub의 **Settings → Pages → Build and deployment → GitHub Actions**를 확인한다. `variant/thread_support=false` 설정으로 별도 cross-origin isolation 헤더는 필요하지 않다. 배포 실패여도 build job의 성공한 artifact가 있다면 파일을 다운로드해 로컬 HTTP 서버에서 실행 가능하다.

## 남은 검증
Chrome/Firefox에서 화면/입력/오디오/60종 카탈로그/4오브/고정 표적을 실제로 확인해야 한다. 300명 적과 4오브 극한 조건은 웹 단일 스레드에서 별도 성능 측정. 검증되지 않은 조합이나 기존 마법 버그는 웹에서도 남는다.


## 2026-10-30 실제 CI 검증 결과 (기록)

- 성공한 [GitHub Actions 빌드 #41025713108](https://github.com/LittleEvasn/witchlings-mayhem/actions/runs/41025713108): Godot v4.6.2.stable Linux 정식 에디터 및 공식 Web export templates 사용.
- Python 임시 프로젝트 설정 검사 3건 **통과**.
- 실제 Godot headless 60프레임 훈련장 부팅 **성공**.
- Web 내보내기 **성공**: `index.html`, `index.js`, `index.wasm`, `index.pck` 포함.
- [다운로드 가능한 웹 빌드 artifact](https://github.com/LittleEvasn/witchlings-mayhem/actions/runs/41025713108/artifacts/12963104407) 생성 확인. 원래 파일은 GitHub Actions에 30일 보관 설정.
- GitHub Pages 배포 **미완료**: `actions/configure-pages@v5`가 사이트 생성 중 `Resource not accessible by integration` 403 오류를 반환. GitHub 관리자 권한으로 저장소 **Settings → Pages → Build and deployment: GitHub Actions** 선택 후 다시 배포해야 함.
- 브라우저 화면 수동 검증 **미수행**: 현재 검사 컨테이너의 Chromium에서 `http://127.0.0.1` 접속이 `ERR_BLOCKED_BY_ADMINISTRATOR`로 막힘. 게임 자체의 WebGL 오류로 해석하지 않는다.
- 본게임 코드, 원본 `project.godot`, 마법 효과 60종은 변경하지 않음.
