---
title: "Migrating from ObservableObject to @Observable"
date: 2025-09-10
summary: "What changes when a SwiftUI view model moves to the Observation framework — and the two property-wrapper mistakes that bite during migration."
keywords: ["Observation", "SwiftUI"]
---

The Observation framework (iOS 17+) replaces `ObservableObject` + `@Published` with the `@Observable` macro. Views track exactly the properties they read in `body`, so unrelated changes no longer re-render them.

## Before and after

```swift
// Before
final class CartModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var coupon: String?
}

struct CartView: View {
    @StateObject private var model = CartModel()
    var body: some View { List(model.items) { Text($0.name) } }
}

// After
@Observable
final class CartModel {
    var items: [Item] = []
    var coupon: String?
}

struct CartView: View {
    @State private var model = CartModel()
    var body: some View { List(model.items) { Text($0.name) } }
}
```

Changing `coupon` no longer re-evaluates `CartView.body`, because the view never read it.

## Property wrapper mapping

| Old | New |
| --- | --- |
| `@StateObject` | `@State` |
| `@ObservedObject` | plain `let`/`var` |
| `@EnvironmentObject` | `@Environment(CartModel.self)` |
| `$model.value` bindings | `@Bindable var model` |

## Mistakes to avoid

1. **Keeping `@ObservedObject` for owned models.** With `@Observable`, an owned model must be `@State`, otherwise it's recreated whenever the parent re-renders.
2. **Expecting `@State` to create lazily.** `@State private var model = CartModel()` runs the initializer on every view init (the extra instance is discarded). Keep initializers cheap, or create the model in a `.task`.

Test the migration by adding `let _ = Self._printChanges()` to `body` and comparing re-render counts.
