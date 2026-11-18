# vanilla-rnn-init

Haskell로 RNN을 구현했습니다! 주요 특징은 다음과 같습니다:

## 구현된 기능

### 1. 기본 RNN 구조

입력-은닉층, 은닉층-은닉층(순환), 은닉층-출력층 가중치
편향(bias) 벡터들


### 2. 행렬/벡터 연산

행렬-벡터 곱셈, 벡터 덧셈/뺄셈
외적(outer product), 전치 행렬
순수 함수형으로 구현


### 3. 활성화 함수

Tanh (은닉층용)
Softmax (출력층용)
각각의 미분 함수


### 4. Forward Propagation

한 타임스텝 처리
시퀀스 전체 처리
은닉 상태 관리


### 5. Backward Propagation (BPTT)

그래디언트 구조 정의
파라미터 업데이트
Cross-Entropy 손실 함수



## 실행 방법

Stack을 설치하고, 포맷터와 린터를 설치한 뒤 세 명령이 모두 `PATH`에 포함되어 있는지 확인합니다.

```sh
stack install stylish-haskell hlint
```

Bash:

```sh
./scripts/run.sh
```

PowerShell:

```powershell
.\scripts\run.ps1
```

두 스크립트는 현재 작업 디렉터리와 관계없이 프로젝트 루트에서
포맷팅 → 린팅 → 빌드 → 테스트 → 실행 순서로 동작합니다.
`Setup.hs`와 `src`, `app`, `test`의 Haskell 소스를 포맷팅하고 린팅하며,
어느 단계든 실패하면 즉시 중단하고 해당 종료 코드를 반환합니다.
스크립트에 전달한 인자는 `vanilla-rnn-init-exe`에 그대로 전달됩니다.
