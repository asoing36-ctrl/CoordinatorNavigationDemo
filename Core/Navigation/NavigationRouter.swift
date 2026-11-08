import UIKit

enum Route: String, Hashable {
    case welcome, redeem, phone, home, secondary, details, lab, labDetail
}
enum PresentationRoute: String { case credentialSheet, uikitFullScreen }
enum BackNavigationPolicy { case allowed, blocked }
/// Safe integration diagnostics; contains no controllers, URLs, codes or screen data.
enum NavigationRejection: String, Equatable, Sendable {
    case invalidStack, unsupportedStackController, controllerInUse
    case presenterUnavailable, alreadyPresenting, routeNotFound, queueFull
}
@MainActor struct Screen {
    let controller: UIViewController
    let route: Route
    var policy: BackNavigationPolicy = .allowed
}
@MainActor protocol NavigationRouting: AnyObject {
    var routes: [Route] { get }
    var presentedRoute: PresentationRoute? { get }
    var backBlocked: Bool { get }
    var onChange: (() -> Void)? { get set }
    func push(_ controller: UIViewController, route: Route, policy: BackNavigationPolicy)
    func pop()
    func popTo(_ route: Route)
    /// Explicit flow completion authority; bypasses ordinary Back restrictions.
    func replaceStack(_ screens: [Screen])
    func setRoot(_ controller: UIViewController, route: Route)
    func present(_ controller: UIViewController, route: PresentationRoute)
    func dismiss()
    @discardableResult func showAlert(_ request: AppAlertRequest, completion: @escaping @MainActor (AppAlertAction) -> Void) -> AlertAdmission
    func setSceneActive(_ active: Bool)
    func cancelAlerts()
    /// Invalidates waiting commands without interrupting UIKit's current transition.
    func cancelPendingNavigation()
}

/// Also catches direct UIKit pop calls and navigation bar Back actions.
@MainActor final class PolicyNavigationController: UINavigationController {
    var permitsBack: (() -> Bool)?
    override func popViewController(animated: Bool) -> UIViewController? {
        guard permitsBack?() != false else { return nil }
        return super.popViewController(animated: animated)
    }
    override func popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        guard permitsBack?() != false else { return nil }
        return super.popToViewController(viewController, animated: animated)
    }
    override func popToRootViewController(animated: Bool) -> [UIViewController]? {
        guard permitsBack?() != false else { return nil }
        return super.popToRootViewController(animated: animated)
    }
}

@MainActor final class NavigationRouter: NSObject, NavigationRouting, UINavigationControllerDelegate, UIGestureRecognizerDelegate, UIAdaptivePresentationControllerDelegate {
    private let navigationController: PolicyNavigationController
    private var metadata: [ObjectIdentifier: Screen] = [:]
    private var queue: [Operation] = []
    private let alerts: AppAlertQueue
    private let maximumPendingNavigation: Int
    private let maximumNavigationBurst: Int
    private var navigationSinceAlert = 0
    // Internal read access lets component tests select through the real renderer
    // adapter boundary; ownership and mutation remain exclusively in this router.
    private(set) var alertPresentation: AlertPresentation?
    private var navigationTransitioning = false
    private var presentationTransitioning = false
    private var transitioning: Bool { navigationTransitioning || presentationTransitioning }
    private var draining = false
    private var notifyingObservers = false
    private var navigationDrainPending = false
    private(set) var presentedRoute: PresentationRoute?
    private weak var presentedController: UIViewController?
    private weak var originalGestureDelegate: (any UIGestureRecognizerDelegate)?
    var onChange: (() -> Void)?
    /// The composition root can record rejected commands or schedule recovery.
    var onRejectedNavigation: (@MainActor (NavigationRejection) -> Void)?
    private enum Operation {
        case push(Screen), pop, popTo(Route), replace([Screen]), present(UIViewController, PresentationRoute), dismiss, dismissForReplacement
        var completesFlow: Bool {
            switch self { case .replace, .dismissForReplacement: return true; default: return false }
        }
        var isProtectedPush: Bool {
            if case .push(let screen) = self { return screen.policy == .blocked }
            return false
        }
        var requiresActiveScene: Bool {
            if case .replace = self { return false } // Root setup must work before first activation.
            return true
        }
    }
    init(navigationController: PolicyNavigationController, maximumPendingNavigation: Int = 32,
         maximumPendingAlerts: Int = 9, maximumNavigationBurst: Int = 4) {
        self.navigationController = navigationController
        self.maximumPendingNavigation = max(2, maximumPendingNavigation)
        self.maximumNavigationBurst = max(1, maximumNavigationBurst)
        alerts = AppAlertQueue(maximumPendingRequests: maximumPendingAlerts)
        super.init()
        navigationController.delegate = self
        navigationController.permitsBack = { [weak self] in self?.backBlocked != true }
        navigationController.loadViewIfNeeded()
        originalGestureDelegate = navigationController.interactivePopGestureRecognizer?.delegate
        navigationController.interactivePopGestureRecognizer?.delegate = self
    }
    var routes: [Route] { navigationController.viewControllers.compactMap { metadata[ObjectIdentifier($0)]?.route } }
    /// Includes native presentation/dismissal cleanup, not merely a queued request.
    var hasAlertPresentation: Bool { alertPresentation != nil }
    private var attachedWindow: UIWindow? {
        navigationController.viewIfLoaded?.window ?? navigationController.presentedViewController?.viewIfLoaded?.window
    }
    var backBlocked: Bool {
        guard let top = navigationController.topViewController else { return false }
        return metadata[ObjectIdentifier(top)]?.policy == .blocked
    }
    func push(_ controller: UIViewController, route: Route, policy: BackNavigationPolicy = .allowed) {
        enqueue(.push(Screen(controller: controller, route: route, policy: policy)))
    }
    func pop() { guard !backBlocked else { return }; enqueue(.pop) }
    func popTo(_ route: Route) { guard !backBlocked else { return }; enqueue(.popTo(route)) }
    func replaceStack(_ screens: [Screen]) {
        guard !screens.isEmpty,
              Set(screens.map { ObjectIdentifier($0.controller) }).count == screens.count,
              Set(screens.map(\.route)).count == screens.count,
              screens.allSatisfy({ supportsStack($0.controller) }) else {
            onRejectedNavigation?(.invalidStack)
            return
        }
        guard screens.allSatisfy({ canEnterStack($0.controller, beforeQueuedDismissal: true) }) else {
            onRejectedNavigation?(.controllerInUse)
            return
        }
        cancelPendingNavigation() // Discard obsolete commands when explicitly ending/resetting a flow.
        // Install the complete, bounded flow-completion prefix before alert
        // cleanup can synchronously resume the runner.
        if navigationController.presentedViewController != nil { queue.append(.dismissForReplacement) }
        queue.append(.replace(screens))
        let cancellingFlow = alerts.current?.scope == .flow
        alerts.cancel(scope: .flow)
        if cancellingFlow { alertPresentation?.cancel() }
        drain()
    }
    func setRoot(_ controller: UIViewController, route: Route) { replaceStack([Screen(controller: controller, route: route)]) }
    func present(_ controller: UIViewController, route: PresentationRoute) { enqueue(.present(controller, route)) }
    func dismiss() { enqueue(.dismiss) }
    @discardableResult func showAlert(_ request: AppAlertRequest, completion: @escaping @MainActor (AppAlertAction) -> Void = { _ in }) -> AlertAdmission {
        let admission = alerts.enqueue(request, completion: completion)
        drain()
        return admission
    }
    func setSceneActive(_ active: Bool) {
        alerts.sceneIsActive = active
        alertPresentation?.setSceneActive(active)
        if active { drain() }
    }
    func cancelAlerts() {
        alerts.cancelAll()
        alertPresentation?.cancel()
    }
    func cancelPendingNavigation() { queue.removeAll() }
    private func supportsStack(_ controller: UIViewController) -> Bool {
        !(controller is UINavigationController) && !(controller is UITabBarController) && !(controller is UIAlertController)
    }
    private func isDetached(_ controller: UIViewController) -> Bool {
        controller.parent == nil && controller.presentingViewController == nil &&
            controller.viewIfLoaded?.window == nil && !controller.isBeingPresented && !controller.isBeingDismissed
    }
    private func canEnterStack(_ controller: UIViewController, beforeQueuedDismissal: Bool) -> Bool {
        if navigationController.viewControllers.contains(where: { $0 === controller }) { return true }
        if beforeQueuedDismissal {
            if controller === presentedController { return true }
            if transitioning, metadata[ObjectIdentifier(controller)] != nil { return true }
        }
        return isDetached(controller)
    }
    /// True means an owned presentation or registered native completion now
    /// owns the next turn; a fairness yield must not run more navigation first.
    @discardableResult private func presentNextAlert() -> Bool {
        guard alerts.pendingCount > 0, alerts.sceneIsActive,
              let window = navigationController.viewIfLoaded?.window ?? navigationController.presentedViewController?.viewIfLoaded?.window,
              let root = window.rootViewController else { return false }
        let presenter = AlertPresentation.visibleController(from: root)
        guard !(presenter is UIAlertController) else { return false }
        if let transition = presenter.transitionCoordinator {
            let registered = transition.animate(alongsideTransition: nil) { [weak self] _ in
                DispatchQueue.main.async { [weak self] in self?.drain() }
            }
            if registered { return true }
        }
        guard !presenter.isBeingPresented, !presenter.isBeingDismissed,
              let request = alerts.beginNext() else { return false }
        navigationSinceAlert = 0
        let presentation = AlertPresentation(request: request, presenter: presenter) { [weak self] result in
            guard let self else { return }
            self.alertPresentation = nil
            if let result { self.alerts.complete(id: request.id, action: result) }
            else { self.alerts.cancel(id: request.id) }
            self.drain()
        }
        alertPresentation = presentation
        presentation.present()
        return alertPresentation != nil
    }
    private func enqueue(_ operation: Operation) {
        // Keep the first adjacent push, matching execution-time route deduplication.
        // Do not coalesce across a pop/dismiss/replacement, which changes its meaning.
        if case .push(let next) = operation, case .push(let waiting)? = queue.last,
           next.route == waiting.route { return }
        // The single active protected flow can require Redeem then Phone before
        // UIKit becomes available. Two bounded reserve slots keep both reachable
        // without evicting accepted ordinary commands or silently losing a flow.
        let occupied = max(0, queue.count - (operation.isProtectedPush ? 2 : 0))
        guard occupied < maximumPendingNavigation else { onRejectedNavigation?(.queueFull); return }
        queue.append(operation)
        drain()
    }
    private func drain() {
        guard !draining, !notifyingObservers, !navigationDrainPending, !transitioning, alertPresentation == nil else { return }
        draining = true
        defer { draining = false }
        var processed = 0
        while !navigationDrainPending, !transitioning, alertPresentation == nil {
            // Bound synchronous no-op/rejection batches without dropping accepted work.
            if processed == 64 {
                DispatchQueue.main.async { [weak self] in self?.drain() }
                return
            }
            processed += 1
            guard !queue.isEmpty else {
                let before = alerts.pendingCount
                presentNextAlert()
                if alertPresentation == nil, alerts.pendingCount < before { continue }
                return
            }
            if navigationSinceAlert >= maximumNavigationBurst, !queue[0].completesFlow,
               alerts.pendingCount > 0 {
                let before = alerts.pendingCount
                if presentNextAlert() { return }
                if alerts.pendingCount < before { continue }
            }
            if !alerts.sceneIsActive, attachedWindow != nil, queue[0].requiresActiveScene { return }
            let operation = queue.removeFirst()
            // Commit scheduler state before callbacks can enqueue more work.
            if operation.completesFlow { navigationSinceAlert = 0 }
            else { navigationSinceAlert = min(maximumNavigationBurst, navigationSinceAlert + 1) }
            execute(operation)
        }
    }
    private func execute(_ operation: Operation) {
        let animatedStack = navigationController.viewIfLoaded?.window != nil && navigationController.presentedViewController == nil
        switch operation {
        case .push(let screen):
            guard supportsStack(screen.controller) else { onRejectedNavigation?(.unsupportedStackController); return }
            guard !routes.contains(screen.route) else { return }
            guard !navigationController.viewControllers.contains(where: { $0 === screen.controller }),
                  isDetached(screen.controller) else { onRejectedNavigation?(.controllerInUse); return }
            metadata[ObjectIdentifier(screen.controller)] = screen
            screen.controller.navigationItem.hidesBackButton = screen.policy == .blocked
            navigationTransitioning = animatedStack
            navigationController.pushViewController(screen.controller, animated: animatedStack)
        case .pop:
            guard !backBlocked, navigationController.viewControllers.count > 1 else { return }
            navigationTransitioning = animatedStack
            _ = navigationController.popViewController(animated: animatedStack)
        case .popTo(let route):
            guard !backBlocked else { return }
            guard let target = navigationController.viewControllers.first(where: { metadata[ObjectIdentifier($0)]?.route == route }) else {
                onRejectedNavigation?(.routeNotFound)
                return
            }
            guard target !== navigationController.topViewController else { return }
            navigationTransitioning = animatedStack
            _ = navigationController.popToViewController(target, animated: animatedStack)
        case .replace(let screens):
            guard screens.allSatisfy({ canEnterStack($0.controller, beforeQueuedDismissal: false) }) else {
                onRejectedNavigation?(.controllerInUse)
                return
            }
            for screen in screens { metadata[ObjectIdentifier(screen.controller)] = screen }
            // Nonanimated changes still have a UIKit display lifecycle. Do not
            // let an immediately submitted push overtake the new visible root.
            let visible = navigationController.viewIfLoaded?.window != nil && navigationController.presentedViewController == nil
            navigationTransitioning = visible && navigationController.topViewController !== screens.last?.controller
            navigationController.setViewControllers(screens.map(\.controller), animated: false)
            // Reusing the same top may not emit didShow, but still reserves this
            // turn while UIKit updates the stack and navigation items.
            if visible { deferNavigationDrain() }
        case .present(let controller, let route):
            // UIKit does not complete a presentation from a detached view controller.
            guard navigationController.presentedViewController == nil else { onRejectedNavigation?(.alreadyPresenting); return }
            guard navigationController.viewIfLoaded?.window != nil else { onRejectedNavigation?(.presenterUnavailable); return }
            guard isDetached(controller) else { onRejectedNavigation?(.controllerInUse); return }
            presentedController = controller
            presentedRoute = route
            presentationTransitioning = true
            navigationController.present(controller, animated: true) { [weak self] in self?.completePresentation() }
            controller.presentationController?.delegate = self
        case .dismiss, .dismissForReplacement:
            guard navigationController.presentedViewController != nil else { return }
            presentationTransitioning = true
            navigationController.dismiss(animated: attachedWindow != nil) { [weak self] in
                self?.presentedController = nil
                self?.presentedRoute = nil
                self?.completePresentation()
            }
        }
        synchronize()
    }
    private func synchronize() {
        // An interactive pop temporarily removes its source from viewControllers.
        // UIKit may restore it on cancellation. Prune only the completed stack,
        // and do not disable the gesture that is currently driving that transition.
        if !transitioning {
            let retained = Set(navigationController.viewControllers.map(ObjectIdentifier.init))
            metadata = metadata.filter { retained.contains($0.key) }
            navigationController.topViewController?.navigationItem.hidesBackButton = backBlocked
            navigationController.interactivePopGestureRecognizer?.isEnabled = !backBlocked && navigationController.viewControllers.count > 1
        }
        let wasNotifying = notifyingObservers
        notifyingObservers = true
        defer { notifyingObservers = wasNotifying }
        onChange?()
    }
    private func completePresentation() { presentationTransitioning = false; synchronize(); drain() }
    private func deferNavigationDrain() {
        guard !navigationDrainPending else { return }
        navigationDrainPending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.navigationDrainPending = false
            self.drain()
        }
    }
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        // Track user-initiated transitions too, including an interactive pop that cancels.
        if animated || (navigationController.viewIfLoaded?.window != nil && navigationController.presentedViewController == nil) {
            navigationTransitioning = true
        }
    }
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        navigationTransitioning = false
        if navigationController.viewIfLoaded?.window != nil { deferNavigationDrain() }
        synchronize()
        // didShow confirms completion (including cancellation). Start the next command
        // after UIKit returns from its delegate callback, including commands
        // submitted synchronously after setViewControllers returns. Detached
        // stack construction remains synchronous and does not reserve a turn.
        if !navigationDrainPending { DispatchQueue.main.async { [weak self] in self?.drain() } }
    }
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        guard presentationController.presentedViewController === presentedController,
              let transition = presentationController.presentedViewController.transitionCoordinator else { return }
        presentationTransitioning = true
        let registered = transition.animate(alongsideTransition: nil) { [weak self] context in
            // A cancelled swipe leaves the same sheet onscreen and releases queued work.
            if context.isCancelled { self?.completePresentation() }
        }
        if !registered { completePresentation() }
    }
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        guard presentationController.presentedViewController === presentedController else { return }
        presentedController = nil
        presentedRoute = nil
        completePresentation()
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard !backBlocked, !transitioning, !navigationDrainPending, navigationController.viewControllers.count > 1 else { return false }
        return originalGestureDelegate?.gestureRecognizerShouldBegin?(gestureRecognizer) ?? true
    }
}
