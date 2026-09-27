---
title: "Actor Reentrancy, Explained"
date: 2025-01-22
summary: "Actors prevent data races, not race conditions. Every `await` inside an actor is a point where state can change under you."
keywords: ["Concurrency", "Swift"]
---

Swift actors serialize access to their mutable state, which eliminates **data races**. They do not make multi-step logic atomic. Every `await` inside an actor method is a suspension point, and while the method is suspended the actor is free to run *other* calls. This is **actor reentrancy**.

## The bug

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

Two concurrent calls for the same URL both miss the cache and both download. Nothing crashes, but work is duplicated — and in less forgiving code, invariants break.

## The fix: cache the in-flight task

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

State is mutated **before** the first `await`, so the second caller sees the in-flight `Task` and awaits the same result.

## Rules of thumb

- Treat each `await` in an actor as "the world may have changed". Re-check state after it.
- Do synchronous state changes before suspending.
- `@MainActor` code is reentrant too — a `Task` in a view model can interleave with UI events.
- Structured concurrency (`async let`, `TaskGroup`) doesn't change this; it's about how the actor schedules work.
