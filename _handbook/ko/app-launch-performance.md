---
title: "앱 실행 성능"
date: 2025-11-03
summary: "콜드 런치 시간을 측정하는 방법, `main` 이전에 시스템이 하는 일, 그리고 앱이 주로 시간을 가장 많이 잃는 곳."
lang: ko
translation_of: _handbook/app-launch-performance.md
translation_hash: edfaf0f63ae60df8
keywords: ["Performance", "Instruments"]
---

실행 시간은 사용자가 처음 느끼는 성능입니다. Apple의 가이드는 탭한 뒤 **400ms** 안에 첫 프레임을 그리는 것을 목표로 합니다.

## 측정

- **Xcode Organizer › Launch Time**에서 실제 사용자 기기의 백분위 수치를 볼 수 있습니다.
- Instruments의 **App Launch** 템플릿은 한 번의 실행을 단계별로 나눠 보여 줍니다.
- 테스트에서는 `XCTApplicationLaunchMetric`으로 CI에서의 성능 저하를 추적합니다.

항상 실제 기기에서 Release 빌드로 *콜드* 런치를 측정하세요 — 시뮬레이터와 Debug 빌드는 실제를 대표하지 못합니다.

## 단계

1. **Pre-main**: dyld가 동적 프레임워크를 로드·링크하고 정적 이니셜라이저를 실행합니다. 동적 프레임워크가 적을수록 실행이 빨라집니다. 합치거나 정적으로 링크하세요.
2. **`UIApplicationMain`부터 첫 프레임까지**: `application(_:didFinishLaunchingWithOptions:)`, scene 설정, 루트 뷰 생성.
3. **확장 실행(extended launch)**: 실제 첫 콘텐츠를 불러오는 단계.

## 흔한 개선 방법

- SDK 초기화(분석, 크래시 리포팅, 광고)는 첫 프레임 이후로 미루거나 메인 스레드 밖으로 옮기세요.
- 실행 중에 큰 파일을 읽거나 Core Data에 동기적으로 접근하지 마세요.
- 부수 효과가 있는 `+load` / 정적 이니셜라이저를 피하세요.
- 직접 작성한 실행 코드는 `os_signpost`로 감싸서 Instruments에서 이름과 함께 보이게 하세요.

릴리스마다 실행 시간을 추적하세요. 성능 저하를 막는 장치 없이 한 최적화는 몇 달 안에 무너집니다.
