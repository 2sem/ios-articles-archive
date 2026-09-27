---
title: "Swift Concurrency Cheat Sheet"
date: 2026-02-08
summary: "The Swift Concurrency primitives you use daily — async/await, Task, TaskGroup, actors, Sendable — with the one rule to remember for each."
keywords: ["Concurrency", "Swift"]
---

| Tool | Use it for | Remember |
| --- | --- | --- |
| `async`/`await` | Calling asynchronous work sequentially | `await` marks a suspension point; state may change across it |
| `async let` | A fixed number of parallel child tasks | Children are cancelled if the parent scope exits early |
| `TaskGroup` | A dynamic number of parallel child tasks | Results arrive in completion order, not submission order |
| `Task { }` | Starting async work from sync code | Inherits actor isolation and priority; **you** own cancellation |
| `Task.detached` | Work that must not inherit context | Rarely needed; prefer `Task` + a `nonisolated` function |
| `actor` | Protecting mutable state | Reentrant — re-check state after every `await` |
| `@MainActor` | UI state and UIKit/SwiftUI calls | Annotate types, not scattered call sites |
| `Sendable` | Values crossing isolation domains | Value types of Sendable parts are Sendable automatically |

## Cancellation is cooperative

Cancelling a task only sets a flag. Long-running loops must check it:

```swift
for item in items {
    try Task.checkCancellation()
    await process(item)
}
```

## Bridging callback APIs

```swift
func location() async throws -> CLLocation {
    try await withCheckedThrowingContinuation { continuation in
        manager.requestLocation { result in
            continuation.resume(with: result) // resume exactly once
        }
    }
}
```

## Swift 6 strict concurrency

Turn on complete checking module by module. Fix `Sendable` warnings at type definitions first; each fix removes many call-site warnings. Reach for `@unchecked Sendable` only with a lock and a comment explaining why it's safe.
