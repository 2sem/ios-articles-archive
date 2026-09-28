---
title: "Actor 재진입성(reentrancy) 이해하기"
date: 2025-01-22
summary: "Actor는 데이터 레이스를 막아 주지만 경쟁 상태(race condition)까지 막아 주지는 않습니다. Actor 안의 모든 `await`는 상태가 바뀔 수 있는 지점입니다."
lang: ko
translation_of: _articles/2025-01-22-actor-reentrancy-explained.md
translation_hash: 89556f8740e259fb
keywords: ["Concurrency", "Swift"]
---

Swift actor는 가변 상태에 대한 접근을 직렬화해서 **데이터 레이스(data race)**를 없애 줍니다. 하지만 여러 단계로 이루어진 로직을 원자적으로 만들어 주지는 않습니다. Actor 메서드 안의 모든 `await`는 일시 중단 지점(suspension point)이고, 메서드가 중단된 동안 actor는 *다른* 호출을 자유롭게 실행할 수 있습니다. 이것이 **actor 재진입성(reentrancy)**입니다.

## 버그

```swift
actor ImageCache {
    private var cache: [URL: Image] = [:]

    func image(for url: URL) async throws -> Image {
        if let cached = cache[url] { return cached }
        let image = try await download(url)   // suspension point
        cache[url] = image                     // another call may have written here already
        return image
    }
}
```

같은 URL에 대한 두 번의 동시 호출이 모두 캐시를 놓치고, 둘 다 다운로드합니다. 크래시는 나지 않지만 작업이 중복되고 — 덜 관대한 코드에서는 불변 조건이 깨집니다.

## 해결: 진행 중인 Task를 캐시하기

```swift
actor ImageCache {
    private var tasks: [URL: Task<Image, Error>] = [:]

    func image(for url: URL) async throws -> Image {
        if let task = tasks[url] { return try await task.value }
        let task = Task { try await download(url) }
        tasks[url] = task                      // written before the first await
        return try await task.value
    }
}
```

상태를 첫 번째 `await` **이전에** 변경하므로, 두 번째 호출자는 진행 중인 `Task`를 보고 같은 결과를 기다립니다.

## 경험 법칙

- Actor 안의 각 `await`를 "세상이 바뀌었을 수 있다"로 취급하세요. `await` 이후에는 상태를 다시 확인합니다.
- 동기적인 상태 변경은 일시 중단 전에 끝내세요.
- `@MainActor` 코드도 재진입합니다 — 뷰 모델의 `Task`는 UI 이벤트와 교차 실행될 수 있습니다.
- 구조화된 동시성(structured concurrency, `async let`, `TaskGroup`)을 써도 이 점은 바뀌지 않습니다. 이것은 actor가 작업을 스케줄링하는 방식의 문제입니다.
