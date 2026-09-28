---
title: "Swift Concurrency 치트 시트"
date: 2026-02-08
summary: "매일 쓰는 Swift Concurrency 기본 요소 — async/await, Task, TaskGroup, actor, Sendable — 와 각각에 대해 기억해야 할 규칙 하나씩."
lang: ko
translation_of: _handbook/concurrency-cheat-sheet.md
translation_hash: f4d4cba8782d2b6c
keywords: ["Concurrency", "Swift"]
---

| 도구 | 용도 | 기억할 점 |
| --- | --- | --- |
| `async`/`await` | 비동기 작업을 순차적으로 호출 | `await`는 일시 중단 지점입니다. 그 전후로 상태가 바뀔 수 있습니다 |
| `async let` | 개수가 정해진 병렬 자식 작업 | 부모 스코프가 일찍 끝나면 자식 작업은 취소됩니다 |
| `TaskGroup` | 개수가 동적인 병렬 자식 작업 | 결과는 제출 순서가 아니라 완료 순서로 도착합니다 |
| `Task { }` | 동기 코드에서 비동기 작업 시작 | actor 격리와 우선순위를 상속합니다. 취소 책임은 **여러분**에게 있습니다 |
| `Task.detached` | 컨텍스트를 상속하면 안 되는 작업 | 거의 필요 없습니다. `Task` + `nonisolated` 함수를 우선 고려하세요 |
| `actor` | 가변 상태 보호 | 재진입(reentrant)합니다 — `await` 이후마다 상태를 다시 확인하세요 |
| `@MainActor` | UI 상태와 UIKit/SwiftUI 호출 | 호출 지점마다 흩어 놓지 말고 타입에 붙이세요 |
| `Sendable` | 격리 도메인을 넘나드는 값 | Sendable 요소로만 구성된 값 타입은 자동으로 Sendable입니다 |

## 취소는 협력적입니다

Task를 취소하면 플래그만 설정됩니다. 오래 실행되는 반복문은 직접 확인해야 합니다.

```swift
for item in items {
    try Task.checkCancellation()
    await process(item)
}
```

## 콜백 API 연결하기

```swift
func location() async throws -> CLLocation {
    try await withCheckedThrowingContinuation { continuation in
        manager.requestLocation { result in
            continuation.resume(with: result) // resume exactly once
        }
    }
}
```

## Swift 6 엄격한 동시성 검사

complete checking은 모듈 단위로 하나씩 켜세요. `Sendable` 경고는 타입 정의부터 고치세요. 하나를 고치면 호출 지점의 경고가 여러 개 사라집니다. `@unchecked Sendable`은 lock과 함께, 왜 안전한지 설명하는 주석을 달 때만 쓰세요.
