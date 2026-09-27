---
title: "App Launch Performance"
date: 2025-11-03
summary: "How to measure cold launch time, what the system does before `main`, and where apps usually lose the most time."
keywords: ["Performance", "Instruments"]
---

Launch time is the first performance impression users get. Apple's guidance targets the first frame within **400 ms** of the tap.

## Measure

- **Xcode Organizer › Launch Time** shows real-world percentiles from users' devices.
- The **App Launch** template in Instruments breaks a single launch into phases.
- In tests, `XCTApplicationLaunchMetric` tracks regressions in CI.

Always measure a *cold* launch on a real device in a Release build — the simulator and Debug builds are not representative.

## Phases

1. **Pre-main**: dyld loads and links dynamic frameworks, runs static initializers. Fewer dynamic frameworks means faster launch; merge them or link statically.
2. **`UIApplicationMain` to first frame**: `application(_:didFinishLaunchingWithOptions:)`, scene setup, root view creation.
3. **Extended launch**: loading the first real content.

## Common fixes

- Defer SDK initialization (analytics, crash reporting, ads) until after the first frame, or move it off the main thread.
- Don't read large files or hit Core Data synchronously during launch.
- Avoid `+load` / static initializers with side effects.
- Use `os_signpost` around your own launch work so it shows up in Instruments with names.

Track launch time on every release; optimization without a regression guard decays within months.
