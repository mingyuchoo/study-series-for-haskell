<p align="center">
  <a href="https://github.com/mingyuchoo/haskell-study-series/blob/main/LICENSE"><img alt="license" src="https://img.shields.io/github/license/mingyuchoo/haskell-study-series"/></a>
  <a href="https://github.com/mingyuchoo/haskell-setup-series/issues"><img alt="Issues" src="https://img.shields.io/github/issues/mingyuchoo/haskell-setup-series?color=appveyor" /></a>
  <a href="https://github.com/mingyuchoo/haskell-setup-series/pulls"><img alt="GitHub pull requests" src="https://img.shields.io/github/issues-pr/mingyuchoo/haskell-setup-series?color=appveyor" /></a>
</p>

# README

## Haskell 프로그래밍 언어란

**Haskell의 근본 철학은 "행위를 정보로 물화(reify)하라"입니다. 범주론은 그 철학을 실현하는 수학적 언어이지, 철학 그 자체는 아닙니다.**

이 구분이 중요한 이유는 이렇습니다.

Haskell의 출발점은 순수 함수형 프로그래밍이라는 제약입니다. 부수 효과를 직접 수행할 수 없으므로, 행위를 기술하는 값을 만들어야 합니다. 이 제약이 자연스럽게 "행위의 정보화"를 강제합니다. 그런데 행위를 정보로 바꾸면 즉시 문제가 생깁니다. 그 정보들을 어떻게 조합하고, 어떤 법칙이 성립해야 프로그래머가 안전하게 추론할 수 있는가? 바로 여기서 범주론이 등장합니다.

범주론이 제공하는 것은 **조합의 문법**입니다. Functor는 구조 보존 사상의 법칙, Monad는 순차 합성의 법칙, Monoid는 결합의 법칙을 줍니다. 이 법칙들 덕분에 프로그래머는 행위를 정보로 바꾼 뒤에도 등식 추론(equational reasoning)을 할 수 있습니다. `f . id = f`, `join . fmap join = join . join` 같은 등식이 성립하기 때문에 코드를 대수적으로 리팩터링할 수 있습니다.

그러나 Haskell이 범주론에 **전적으로** 의존하는 것은 아닙니다. 타입클래스 자체는 범주론이 아니라 한정된 다형성(ad-hoc polymorphism)의 메커니즘이고, 대수적 데이터 타입은 범주론보다는 보편 대수(universal algebra)에 뿌리를 두고 있으며, 타입 시스템의 핵심인 System F는 논리학과 람다 대수에서 옵니다. 범주론은 이 여러 수학적 토대 중 하나입니다.

**그래서 더 정확한 진술은 이렇습니다.**

Haskell의 근본 철학은 **"모든 행위를 일급 정보로 만들어, 수학적 법칙 하에서 조합 가능하게 하라"**입니다. 범주론은 그 법칙들의 가장 강력한 공급원 역할을 합니다. 특히 효과의 조합(Functor-Applicative-Monad 계층)에서 범주론의 역할이 결정적입니다. 하지만 Haskell을 "범주론의 프로그래밍 언어"라고 부르는 것보다는, **"행위를 정보로 물화하되, 그 물화된 정보의 조합 법칙을 범주론에서 빌려오는 언어"**라고 보는 것이 더 정확합니다.

결국 Haskell이 추구하는 것은 프로그램 전체를 **등식으로 추론 가능한 수학적 대상**으로 만드는 것이고, 범주론은 그 목표에 가장 잘 부합하는 도구였던 것입니다.

## How to make dev. environment

```
$ nix develop
```

## Basic Cabal Commands

```bash
$ mkdir {project-name}
$ cd {project-name}
$ cabal init

...

$ cabal install —only-dependencies
$ cabal update
$ cabal configure
$ cabal check
$ cabal build
$ cabal run
$ cabal sdist
$ cabal upload
$ cabal install
```

## Basic Stack Commands

```bash
$ stack new {project-name}
# or
$ stack new {project-name} quanterall/basic

$ stack build --test --file-watch --watch-all
# or
# build more faster
$ stack build --fast -j4 --ghc-options "-j16 +RTS -A256m -RTS"

$ stack test --file-watch --watch-all
# or
# test automatically
$ ghcid --command "stack ghci test/Spec.hs"

# https://docs.haskellstack.org/en/stable/build_command/
$ stack test --coverage --fast --file-watch --watch-all --haddock

$ stack run
````

## Install Haskell applications using Stack

```bash
stack install \
  ghcid       \
  hindent     \
  hlint       \
  hoogle      \
  ihaskell    \
  ormolu      \
  stylish-haskell
```
## Reformat using Stylish-haskell

```bash
$ stylish-haskell -ri **/*.hs
```
