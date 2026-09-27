---
title: "Finding Retain Cycles in Closures"
date: 2024-03-18
summary: "Why `[weak self]` is not a reflex, how to spot a retain cycle with the Memory Graph Debugger, and when `unowned` is actually safe."
keywords: ["Memory Management", "Debugging"]
---

ARC frees an object when its strong reference count reaches zero. A **retain cycle** happens when two objects — or an object and a closure it stores — hold strong references to each other, so neither count ever reaches zero.

## The classic shape

```swift
final class ProfileViewModel {
    var onUpdate: (() -> Void)?
    var name = ""

    func bind() {
        onUpdate = {
            print(self.name) // self -> onUpdate -> closure -> self
        }
    }
}
```

The view model owns the closure, and the closure captures `self` strongly. Neither is released: a memory leak.

## Capture weakly only when the closure is stored

`[weak self]` is needed when the closure is **escaping and retained by something `self` (transitively) owns**. A closure passed to `UIView.animate` or `DispatchQueue.main.async` is released after it runs, so a strong capture only extends the lifetime briefly — it does not leak.

```swift
onUpdate = { [weak self] in
    guard let self else { return }
    print(self.name)
}
```

## `unowned` is a promise

`unowned` avoids the optional, but crashes if the object is gone when the closure runs. Use it only when the closure's lifetime is strictly shorter than the captured object's — for example, a lazy property closure that references its owner.

## Finding cycles

1. Run the app, exercise the screen, and pop it.
2. Open Xcode's **Debug Memory Graph**. Leaked instances show a purple warning.
3. Confirm with the Leaks instrument in Instruments when the cycle only appears under specific flows.

A cheap guard in debug builds: log in `deinit`. If you pop a screen and never see the log, you have a retain cycle.
