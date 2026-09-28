---
title: "Mastering container views in SwiftUI. Basics."
date: 2024-09-24
author: "Majid Jabrayilov"
source_url: https://swiftwithmajid.com/2024/09/24/mastering-container-views-in-swiftui-basics/
summary: "SwiftUI's new decomposition APIs — `ForEach(subviews:)` and `Group(subviews:)` — let a custom container take apart the views passed to its `@ViewBuilder` content and lay each child out on its own."
keywords: ["SwiftUI", "Layout"]
---

> Summary and notes on [Majid Jabrayilov's article](https://swiftwithmajid.com/2024/09/24/mastering-container-views-in-swiftui-basics/) on Swift with Majid. Read the original for the full walkthrough and screenshots.

## Summary

A container view is a view that holds other views, like `HStack`, `VStack` or `List`. Before this year's SwiftUI release, a custom container could only take a `@ViewBuilder` closure and place its content as one block — for example, a card that wraps whatever you give it in padding, a material background and a shadow. That's already useful for reusing shared styling across screens, but the container couldn't reach *into* its content.

The new decomposition APIs change that. A container can now split its `@ViewBuilder` content into the individual child views and arrange each one however it likes, while callers keep writing plain view lists. The article builds two examples: a horizontally paging carousel, and a "magazine" layout that features the first child and puts the rest in a carousel below it.

## Key points

- **Composition:** a generic `Container<Content: View>` with a `@ViewBuilder var content: Content` property is the classic way to build a reusable container.
- **`ForEach(subviews: content) { subview in … }`** iterates over the children of `content`. Each child can be modified individually — the carousel gives every child `containerRelativeFrame(.horizontal)` inside a `LazyHStack`, with `scrollTargetLayout()` and `.scrollTargetBehavior(.viewAligned)` for paging.
- **`Subview`** is the type of each extracted child. It conforms to `View`, so you can keep applying modifiers; it also has an `id` and exposes the child's *container values* (covered in a follow-up article).
- **`Group(subviews: content) { subviews in … }`** hands you all children at once as a `SubviewsCollection`, a `RandomAccessCollection`. That allows index-based layouts: `subviews[0]` as a featured item, `subviews[1...]` elsewhere.
- Because each `Subview` has an `id`, a slice like `subviews[1...]` can be passed to `ForEach(_:id: \.id)` like plain data.
- The author's takeaway: these APIs fill the missing piece for building customizable, reusable containers. They decompose content and recompose it differently while hiding the layout details from callers.

## Notes

- These APIs require iOS 18 / macOS 15 (the 2024 SwiftUI release).
- The call site doesn't change — callers still write a plain `@ViewBuilder` list, and the container decides how to lay it out:

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

- Use `ForEach(subviews:)` when every child gets the same treatment, and `Group(subviews:)` when position matters (first item, counts, slices).
