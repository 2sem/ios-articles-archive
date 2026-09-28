---
title: "클로저에서 순환 참조 찾기"
date: 2024-03-18
summary: "`[weak self]`를 습관처럼 쓰면 안 되는 이유, Memory Graph Debugger로 순환 참조를 찾는 방법, 그리고 `unowned`가 실제로 안전한 경우."
lang: ko
translation_of: _articles/2024-03-18-finding-retain-cycles-in-closures.md
translation_hash: 81ac77c2c5bc02e5
keywords: ["Memory Management", "Debugging"]
---

ARC는 객체의 강한 참조 카운트가 0이 되면 객체를 해제합니다. **순환 참조(retain cycle)**는 두 객체가 — 또는 객체와 그 객체가 저장한 클로저가 — 서로를 강하게 참조해서 어느 쪽의 카운트도 0이 되지 않을 때 발생합니다.

## 전형적인 형태

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

뷰 모델이 클로저를 소유하고, 클로저는 `self`를 강하게 캡처합니다. 둘 다 해제되지 않으므로 메모리 누수(memory leak)가 생깁니다.

## 클로저가 저장될 때만 약하게 캡처하기

`[weak self]`가 필요한 경우는 클로저가 **escaping이면서 `self`가 (직간접적으로) 소유한 무언가에 의해 유지될 때**입니다. `UIView.animate`나 `DispatchQueue.main.async`에 전달한 클로저는 실행 후 해제되므로, 강한 캡처는 수명을 잠깐 늘릴 뿐 누수를 만들지 않습니다.

```swift
onUpdate = { [weak self] in
    guard let self else { return }
    print(self.name)
}
```

## `unowned`는 약속입니다

`unowned`를 쓰면 옵셔널을 피할 수 있지만, 클로저가 실행될 때 객체가 이미 사라졌다면 크래시가 납니다. 클로저의 수명이 캡처한 객체의 수명보다 확실히 짧을 때만 사용하세요 — 예를 들어 자신의 소유자를 참조하는 lazy 프로퍼티 클로저가 그렇습니다.

## 순환 참조 찾기

1. 앱을 실행해 해당 화면을 사용한 뒤, 화면을 pop 합니다.
2. Xcode의 **Debug Memory Graph**를 엽니다. 누수된 인스턴스에는 보라색 경고가 표시됩니다.
3. 특정 흐름에서만 순환 참조가 나타난다면 Instruments의 Leaks 도구로 확인합니다.

디버그 빌드에서 쓸 수 있는 간단한 안전장치: `deinit`에서 로그를 남기세요. 화면을 pop 했는데 로그가 보이지 않는다면 순환 참조가 있는 것입니다.
