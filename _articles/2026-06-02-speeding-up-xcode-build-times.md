---
title: "Xcode 빌드 시간 줄이기: 실전 체크리스트"
date: 2026-06-02
lang: ko
summary: "모듈화된 앱에서 증분 빌드 시간을 절반으로 줄인 방법 — 타입 체크 경고, 빌드 설정, 모듈 경계 정리."
keywords: ["Build System", "Modularization", "Xcode"]
---

빌드 시간은 팀 전체의 생산성에 곱해지는 비용입니다. 아래는 SPM 기반으로 모듈화된 앱에서 증분 빌드 시간을 줄일 때 효과가 컸던 순서대로 정리한 체크리스트입니다.

## 1. 측정부터

- Xcode의 **Product › Perform Action › Build With Timing Summary**로 어떤 단계가 오래 걸리는지 확인합니다.
- `-Xfrontend -warn-long-function-bodies=200` 과 `-warn-long-expression-type-checking=200` 을 Other Swift Flags에 추가해 타입 체크가 느린 코드를 찾습니다.

## 2. 타입 추론 비용 줄이기

복잡한 리터럴과 연산자 체인은 컴파일러의 타입 체크 시간을 폭발시킵니다. 명시적 타입을 붙이는 것만으로 수 초가 줄어드는 경우가 많습니다.

```swift
// 느림
let total = items.map { $0.price * 1.1 }.reduce(0, +) + shipping ?? 0
// 빠름
let subtotal: Double = items.reduce(0) { $0 + $1.price * 1.1 }
let total: Double = subtotal + (shipping ?? 0)
```

## 3. 빌드 설정

- Debug 구성에서 `Compilation Mode`는 **Incremental**, `Debug Information Format`은 **DWARF**(dSYM 생성 생략)로 둡니다.
- 불필요한 Run Script 단계에 Input/Output 파일을 지정해 매번 실행되지 않도록 합니다.

## 4. 모듈 경계

- 자주 바뀌는 Feature 모듈이 무거운 공용 모듈에 의존하지 않도록 인터페이스 모듈을 분리합니다.
- `public` API를 최소화하면 변경 시 다시 컴파일되는 범위가 줄어듭니다.

결과적으로 증분 빌드가 약 48초에서 21초로 줄었습니다. 무엇보다 **측정 → 가장 큰 병목 하나 해결 → 재측정**의 반복이 핵심입니다.
