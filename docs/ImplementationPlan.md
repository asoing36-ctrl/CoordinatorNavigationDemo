# Implementation plan

The supplied specification is the design authority. Execute autonomously in this new dedicated directory; no existing repository is modified.

1. Define behavior tests for URL validation, backend/account/session rules, transaction serialization, router policy and coordinator flow completion.
2. Implement Sendable domain values, repository protocol, actor-backed deterministic backend, redeem use case and main-actor session store.
3. Implement one intent pipeline and protocol-based main-actor router. Navigation controller owns the stack; delegate completion reconciles routes. Protected routes block ordinary pop, bar Back and gestures; explicit stack replacement completes flows.
4. Implement application composition and three feature coordinators, preserving the pre-redeem authentication snapshot and invalidating stale asynchronous callbacks on reset.
5. Add SwiftUI screens, two real connected UIKit XIBs, debug controls and observed diagnostics.
6. Create native Xcode project, icon assets, URL registration, shared scheme and unit/UI targets. No runtime project generator or dependencies.
7. Build, run available tests, review concurrency/ownership/navigation, fix defects and document exact results.

Review focus: reset during suspended work; multiple URLs during phone association; protected pop and restoration; authenticated stack preservation; XIB loading. Swift 5 language mode with complete concurrency checking, iOS 17 deployment, current Xcode/Swift 6 compiler.

## Presented screens extension

Add two deliberately different presentation examples: a medium/large SwiftUI credential sheet and a full-screen UIKit controller loaded from the existing lab XIB. Home and Secondary expose both; the UIKit lab also exposes the sheet. Feature actions remain coordinator closures and route all presentation/dismissal through NavigationRouting. No second navigation controller or SwiftUI NavigationStack is introduced.

Represent the current modal separately from the actual push stack for diagnostics. Serialize explicit dismissal, reconcile swipe-to-dismiss (including cancellation), suppress duplicate presentation, and dismiss obsolete modals on explicit stack replacement. Tests cover coordinator presentation style, XIB dismissal outlets, stack preservation, ordinary/swipe dismissal, and navigating after a modal closes. Build the native project and attempt the UI suite; report Simulator restrictions accurately.
