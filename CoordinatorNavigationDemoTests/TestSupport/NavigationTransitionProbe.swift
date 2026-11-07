import UIKit

/// Test-only delegate forwards real lifecycle callbacks to the production router.
/// It supplies public UIKit animators so tests can prove a transition actually began.
@MainActor final class NavigationTransitionProbe: NSObject, UINavigationControllerDelegate {
    private weak var navigation: UINavigationController?
    private weak var original: (any UINavigationControllerDelegate)?
    let heldPush = HeldPushAnimator()
    private var shouldHoldPush = true
    private(set) var popAnimator: InteractivePopAnimator?
    private var interaction: UIPercentDrivenInteractiveTransition?
    private var cancellationRequested = false
    private(set) var deliveringDidShow = false
    private(set) var beganTransitionInsideDidShow = false

    init(navigation: UINavigationController) {
        self.navigation = navigation
        original = navigation.delegate
        super.init()
        navigation.delegate = self
    }
    func prepareInteractivePop() {
        shouldHoldPush = false
        cancellationRequested = false
        popAnimator = InteractivePopAnimator()
        interaction = UIPercentDrivenInteractiveTransition()
        interaction?.completionCurve = .linear
    }
    func cancelInteractivePop() {
        guard !cancellationRequested else { return }
        cancellationRequested = true
        interaction?.update(0.35)
        interaction?.cancel()
    }
    func restore() {
        heldPush.finish()
        if popAnimator?.started == true, popAnimator?.completed != true { cancelInteractivePop() }
        if navigation?.delegate === self { navigation?.delegate = original }
    }
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if deliveringDidShow { beganTransitionInsideDidShow = true }
        original?.navigationController?(navigationController, willShow: viewController, animated: animated)
    }
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        deliveringDidShow = true
        defer { deliveringDidShow = false }
        original?.navigationController?(navigationController, didShow: viewController, animated: animated)
    }
    func navigationController(_ navigationController: UINavigationController,
                              animationControllerFor operation: UINavigationController.Operation,
                              from fromVC: UIViewController, to toVC: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
        if operation == .push, shouldHoldPush {
            shouldHoldPush = false
            return heldPush
        }
        // The cancelled interaction belongs to one transition. Later pop/popTo
        // commands must return to UIKit's ordinary animation and interaction.
        if operation == .pop, let popAnimator, !popAnimator.completed { return popAnimator }
        return nil
    }
    func navigationController(_ navigationController: UINavigationController,
                              interactionControllerFor animationController: any UIViewControllerAnimatedTransitioning) -> (any UIViewControllerInteractiveTransitioning)? {
        guard let popAnimator, !popAnimator.completed, animationController === popAnimator else { return nil }
        return interaction
    }
}

@MainActor final class HeldPushAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private(set) var started = false
    private var context: (any UIViewControllerContextTransitioning)?

    nonisolated func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval { 0.25 }
    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        started = true
        context = transitionContext
        if let destination = transitionContext.viewController(forKey: .to),
           let view = transitionContext.view(forKey: .to) {
            view.frame = transitionContext.finalFrame(for: destination)
            transitionContext.containerView.addSubview(view)
        }
        // Explicit finish is the gate. Duration/elapsed time never completes this transition.
    }
    func finish() {
        guard let context else { return }
        self.context = nil
        context.completeTransition(true)
    }
}

@MainActor final class InteractivePopAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private(set) var started = false
    private(set) var completed = false

    nonisolated func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval { 0.25 }
    func animateTransition(using context: any UIViewControllerContextTransitioning) {
        started = true
        guard let from = context.view(forKey: .from), let to = context.view(forKey: .to),
              let destination = context.viewController(forKey: .to) else {
            context.completeTransition(false)
            completed = true
            return
        }
        to.frame = context.finalFrame(for: destination)
        context.containerView.insertSubview(to, belowSubview: from)
        UIView.animate(withDuration: transitionDuration(using: context), delay: 0, options: .curveLinear) {
            from.transform = CGAffineTransform(translationX: context.containerView.bounds.width, y: 0)
        } completion: { [weak self] _ in
            from.transform = .identity
            context.completeTransition(!context.transitionWasCancelled)
            self?.completed = true
        }
    }
}
