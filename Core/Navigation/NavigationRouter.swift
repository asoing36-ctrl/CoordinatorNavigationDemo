import UIKit

enum Route: String, Hashable {
    case welcome, redeem, phone, home, secondary, details, lab, labDetail
}
enum PresentationRoute: String { case credentialSheet, uikitFullScreen }
enum BackNavigationPolicy { case allowed, blocked }
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
    private var transitioning = false
    private(set) var presentedRoute: PresentationRoute?
    private weak var presentedController: UIViewController?
    private weak var originalGestureDelegate: (any UIGestureRecognizerDelegate)?
    var onChange: (() -> Void)?
    private enum Operation {
        case push(Screen), pop, popTo(Route), replace([Screen]), present(UIViewController, PresentationRoute), dismiss
    }
    init(navigationController: PolicyNavigationController) {
        self.navigationController = navigationController
        super.init()
        navigationController.delegate = self
        navigationController.permitsBack = { [weak self] in self?.backBlocked != true }
        navigationController.loadViewIfNeeded()
        originalGestureDelegate = navigationController.interactivePopGestureRecognizer?.delegate
        navigationController.interactivePopGestureRecognizer?.delegate = self
    }
    var routes: [Route] { navigationController.viewControllers.compactMap { metadata[ObjectIdentifier($0)]?.route } }
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
        guard !screens.isEmpty else { return }
        queue.removeAll() // Discard obsolete commands when explicitly ending/resetting a flow.
        if navigationController.presentedViewController != nil { queue.append(.dismiss) }
        enqueue(.replace(screens))
    }
    func setRoot(_ controller: UIViewController, route: Route) { replaceStack([Screen(controller: controller, route: route)]) }
    func present(_ controller: UIViewController, route: PresentationRoute) { enqueue(.present(controller, route)) }
    func dismiss() { enqueue(.dismiss) }
    private func enqueue(_ operation: Operation) { queue.append(operation); drain() }
    private func drain() {
        guard !transitioning, !queue.isEmpty else { return }
        let operation = queue.removeFirst()
        let animated = navigationController.viewIfLoaded?.window != nil || navigationController.presentedViewController?.viewIfLoaded?.window != nil
        switch operation {
        case .push(let screen):
            guard !routes.contains(screen.route) else { drain(); return }
            metadata[ObjectIdentifier(screen.controller)] = screen
            screen.controller.navigationItem.hidesBackButton = screen.policy == .blocked
            transitioning = animated
            navigationController.pushViewController(screen.controller, animated: animated)
        case .pop:
            guard !backBlocked, navigationController.viewControllers.count > 1 else { drain(); return }
            transitioning = animated
            _ = navigationController.popViewController(animated: animated)
        case .popTo(let route):
            guard !backBlocked, let target = navigationController.viewControllers.first(where: { metadata[ObjectIdentifier($0)]?.route == route }), target !== navigationController.topViewController else { drain(); return }
            transitioning = animated
            _ = navigationController.popToViewController(target, animated: animated)
        case .replace(let screens):
            for screen in screens { metadata[ObjectIdentifier(screen.controller)] = screen }
            // Replacements are atomic, with no animation. They are flow completion, not Back.
            navigationController.setViewControllers(screens.map(\.controller), animated: false)
        case .present(let controller, let route):
            // UIKit does not complete a presentation from a detached view controller.
            guard navigationController.viewIfLoaded?.window != nil,
                  navigationController.presentedViewController == nil else { drain(); return }
            presentedController = controller
            presentedRoute = route
            transitioning = true
            navigationController.present(controller, animated: animated) { [weak self] in self?.complete() }
            controller.presentationController?.delegate = self
        case .dismiss:
            guard navigationController.presentedViewController != nil else { drain(); return }
            transitioning = true
            navigationController.dismiss(animated: animated) { [weak self] in
                self?.presentedController = nil
                self?.presentedRoute = nil
                self?.complete()
            }
        }
        synchronize()
        if !transitioning { drain() }
    }
    private func synchronize() {
        let retained = Set(navigationController.viewControllers.map(ObjectIdentifier.init))
        metadata = metadata.filter { retained.contains($0.key) }
        navigationController.topViewController?.navigationItem.hidesBackButton = backBlocked
        navigationController.interactivePopGestureRecognizer?.isEnabled = !backBlocked && navigationController.viewControllers.count > 1
        onChange?()
    }
    private func complete() { transitioning = false; synchronize(); drain() }
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        // Track user-initiated transitions too, including an interactive pop that cancels.
        if animated { transitioning = true }
    }
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        transitioning = false
        synchronize()
        // didShow confirms completion (including cancellation). Start the next command
        // after UIKit has returned from its delegate callback. A nonnil transition
        // coordinator at this point must not strand queued commands.
        DispatchQueue.main.async { [weak self] in self?.drain() }
    }
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        guard presentationController.presentedViewController === presentedController,
              let transition = presentationController.presentedViewController.transitionCoordinator else { return }
        transitioning = true
        let registered = transition.animate(alongsideTransition: nil) { [weak self] context in
            // A cancelled swipe leaves the same sheet onscreen and releases queued work.
            if context.isCancelled { self?.complete() }
        }
        if !registered { complete() }
    }
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        guard presentationController.presentedViewController === presentedController else { return }
        presentedController = nil
        presentedRoute = nil
        complete()
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard !backBlocked, !transitioning, navigationController.viewControllers.count > 1 else { return false }
        return originalGestureDelegate?.gestureRecognizerShouldBegin?(gestureRecognizer) ?? true
    }
}
