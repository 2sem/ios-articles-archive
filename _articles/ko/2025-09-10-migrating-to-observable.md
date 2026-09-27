---
title: "ObservableObject에서 @Observable로 마이그레이션하기"
date: 2025-09-10
summary: "SwiftUI 뷰 모델을 Observation 프레임워크로 옮길 때 무엇이 바뀌는지 — 그리고 마이그레이션 중에 자주 겪는 프로퍼티 래퍼 실수 두 가지."
lang: ko
translation_of: _articles/2025-09-10-migrating-to-observable.md
translation_hash: 5182b79ed8588da1
keywords: ["Observation", "SwiftUI"]
---

Observation 프레임워크(iOS 17+)는 `ObservableObject` + `@Published` 조합을 `@Observable` 매크로로 대체합니다. 뷰는 `body`에서 실제로 읽은 프로퍼티만 추적하므로, 관련 없는 변경으로 다시 렌더링되지 않습니다.

## 변경 전과 후

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

이제 `coupon`을 바꿔도 `CartView.body`가 다시 평가되지 않습니다. 뷰가 그 값을 읽은 적이 없기 때문입니다.

## 프로퍼티 래퍼 대응표

| 기존 | 변경 후 |
| --- | --- |
| `@StateObject` | `@State` |
| `@ObservedObject` | 일반 `let`/`var` |
| `@EnvironmentObject` | `@Environment(CartModel.self)` |
| `$model.value` 바인딩 | `@Bindable var model` |

## 피해야 할 실수

1. **소유한 모델에 `@ObservedObject`를 계속 쓰는 것.** `@Observable`에서는 뷰가 소유한 모델을 반드시 `@State`로 선언해야 합니다. 그렇지 않으면 부모가 다시 렌더링될 때마다 모델이 새로 만들어집니다.
2. **`@State`가 지연 생성될 거라고 기대하는 것.** `@State private var model = CartModel()`은 뷰가 init 될 때마다 이니셜라이저를 실행합니다(추가로 만들어진 인스턴스는 버려집니다). 이니셜라이저를 가볍게 유지하거나, `.task`에서 모델을 생성하세요.

`body`에 `let _ = Self._printChanges()`를 추가해 재렌더링 횟수를 비교하면 마이그레이션 결과를 검증할 수 있습니다.
