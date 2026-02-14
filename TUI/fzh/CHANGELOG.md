# Changelog for `fzh`

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to the
[Haskell Package Versioning Policy](https://pvp.haskell.org/).

## Unreleased

### Added
- 파일 시스템 탐색 시 자동 제외 패턴 (.git, .stack-work, node_modules 등)
- 에러 메시지 개선 (파일 없음, 권한 없음 등 명확한 한국어 메시지)
- UI 개선: 선택 위치 표시 (예: "Position: 3/10")
- CI/CD: GitHub Actions 워크플로우 (빌드, 테스트, 릴리스 자동화)
- 단위 테스트 대폭 확장 (8개 → 22개)
- 상세한 README (사용법, 키바인딩, 설정 방법)

### Changed
- FileSearch 모듈 분리 및 에러 핸들링 강화
- 메타데이터 개선 (synopsis, category, description)
- 테스트 커버리지 향상 (Fuzzy, Types, FileSearch, Event, UI 모듈)

### Fixed
- 테스트 파일 컴파일 오류 수정
- 불필요한 import 제거

## 0.1.0.0 - 2025-02-14
