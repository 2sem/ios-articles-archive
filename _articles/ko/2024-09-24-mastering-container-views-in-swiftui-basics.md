---
title: "SwiftUI 컨테이너 뷰 마스터하기: 기초"
summary: "SwiftUI의 새로운 분해(decomposition) API — `ForEach(subviews:)`와 `Group(subviews:)` — 를 사용하면 커스텀 컨테이너가 `@ViewBuilder` 콘텐츠로 전달된 뷰를 자식 뷰 단위로 나누어 각각 배치할 수 있습니다."
date: 2024-09-24
author: "Majid Jabrayilov"
source_url: https://swiftwithmajid.com/2024/09/24/mastering-container-views-in-swiftui-basics/
lang: ko
translation_of: _articles/2024-09-24-mastering-container-views-in-swiftui-basics.md
translation_hash: 22907ff232d6d9c5
keywords: ["SwiftUI", "Layout"]
---

> Swift with Majid에 실린 [Majid Jabrayilov의 글](https://swiftwithmajid.com/2024/09/24/mastering-container-views-in-swiftui-basics/)을 요약하고 정리한 노트입니다. 전체 설명과 스크린샷은 원문을 참고하세요.

## 요약

컨테이너 뷰는 `HStack`, `VStack`, `List`처럼 다른 뷰를 담는 뷰입니다. 올해 SwiftUI 릴리스 이전에는 커스텀 컨테이너가 `@ViewBuilder` 클로저를 받아 그 콘텐츠를 하나의 덩어리로 배치하는 것까지만 할 수 있었습니다. 예를 들어 전달받은 내용을 padding, material 배경, 그림자로 감싸는 카드 같은 것이죠. 공통 스타일을 여러 화면에서 재사용하기에는 이것만으로도 유용하지만, 컨테이너가 콘텐츠 *내부*에 접근할 수는 없었습니다.

새로운 분해 API가 이 점을 바꿉니다. 이제 컨테이너는 `@ViewBuilder` 콘텐츠를 개별 자식 뷰로 나누고 각각을 원하는 방식으로 배치할 수 있으며, 호출하는 쪽은 여전히 평범한 뷰 목록을 작성하면 됩니다. 글에서는 두 가지 예제를 만듭니다. 가로로 페이징되는 캐러셀, 그리고 첫 번째 자식을 크게 보여 주고 나머지는 아래 캐러셀에 배치하는 "매거진" 레이아웃입니다.

## 핵심 내용

- **구성(composition):** `@ViewBuilder var content: Content` 프로퍼티를 가진 제네릭 `Container<Content: View>`는 재사용 가능한 컨테이너를 만드는 전통적인 방법입니다.
- **`ForEach(subviews: content) { subview in … }`** 는 `content`의 자식 뷰를 순회합니다. 각 자식에 개별적으로 modifier를 적용할 수 있습니다 — 캐러셀은 `LazyHStack` 안에서 모든 자식에 `containerRelativeFrame(.horizontal)`을 주고, 페이징을 위해 `scrollTargetLayout()`과 `.scrollTargetBehavior(.viewAligned)`를 사용합니다.
- **`Subview`** 는 추출된 각 자식의 타입입니다. `View`를 준수하므로 계속 modifier를 붙일 수 있고, `id`를 가지며 자식의 *container values*도 노출합니다(후속 글에서 다룹니다).
- **`Group(subviews: content) { subviews in … }`** 는 모든 자식을 한 번에 `SubviewsCollection`으로 넘겨줍니다. 이 타입은 `RandomAccessCollection`이므로 인덱스 기반 레이아웃이 가능합니다: `subviews[0]`은 대표 항목으로, `subviews[1...]`은 다른 곳에 배치하는 식입니다.
- 각 `Subview`에 `id`가 있으므로 `subviews[1...]` 같은 슬라이스를 일반 데이터처럼 `ForEach(_:id: \.id)`에 넘길 수 있습니다.
- 저자의 결론: 이 API들은 커스터마이즈 가능하고 재사용 가능한 컨테이너를 만드는 데 빠져 있던 조각을 채워 줍니다. 콘텐츠를 분해해 다른 방식으로 다시 구성하면서도, 레이아웃 세부 사항은 호출하는 쪽으로부터 숨길 수 있습니다.

## 노트

- 이 API들은 iOS 18 / macOS 15(2024년 SwiftUI 릴리스)가 필요합니다.
- 호출하는 쪽 코드는 바뀌지 않습니다 — 여전히 평범한 `@ViewBuilder` 목록을 작성하고, 레이아웃은 컨테이너가 결정합니다.

```swift
struct Featured<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack {
            Group(subviews: content) { subviews in
                if let first = subviews.first {
                    first.font(.title)            // highlight the first child
                }
                ForEach(subviews.dropFirst(), id: \.id) { subview in
                    subview.foregroundStyle(.secondary)
                }
            }
        }
    }
}

// Featured {
//     Text("Headline")
//     Text("Second story")
//     Text("Third story")
// }
```

- 모든 자식을 똑같이 다룰 때는 `ForEach(subviews:)`를, 위치가 중요할 때(첫 항목, 개수, 슬라이스)는 `Group(subviews:)`를 사용하세요.
