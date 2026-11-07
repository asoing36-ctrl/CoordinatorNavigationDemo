import UIKit

/// Controlled sheet-shaped presentation using UIKit's real transition context.
/// Programmatic dismiss does not emit adaptive callbacks; the test presentation
/// controller forwards them only after observing a real interactive transition.
/// This tests the router's callback path, not Apple's native sheet pan recognizer.
@MainActor final class InteractivePresentationProbe: NSObject, UIViewControllerTransitioningDelegate {
    private weak var sheet: ControlledSheetPresentationController?
    private let dismissal = SheetTransitionAnimator(presenting: false)
    private var interaction: UIPercentDrivenInteractiveTransition?
    private var requestingInteraction = false
    private var cancellationRequested = false
    private let holdPresentation: Bool
    let heldPresentation = HeldPushAnimator()

    init(holdPresentation: Bool = false) { self.holdPresentation = holdPresentation; super.init() }

    var interactiveDismissalStarted: Bool { dismissal.started && dismissal.wasInteractive && sheet?.observedInteraction == true }
    var adaptiveCallbackForwarded: Bool { sheet?.forwardedWillDismiss == true }
    var completionRegistered: Bool { sheet?.completionRegistered == true }
    var cancelledCompletionObserved: Bool { dismissal.completed && sheet?.observedCancellation == true }
    var forwardedDidDismissCount: Int { sheet?.forwardedDidDismissCount ?? 0 }

    func configure(_ controller: UIViewController) {
        controller.modalPresentationStyle = .custom
        controller.transitioningDelegate = self
        controller.view.backgroundColor = .systemBackground
    }
    func beginDismissal(of controller: UIViewController) {
        interaction = UIPercentDrivenInteractiveTransition()
        interaction?.completionCurve = .linear
        requestingInteraction = true
        controller.dismiss(animated: true)
    }
    func cancelIfNeeded() {
        guard let interaction, !cancellationRequested else { return }
        cancellationRequested = true
        requestingInteraction = false
        interaction.update(0.35)
        interaction.cancel()
    }
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?,
                                source: UIViewController) -> UIPresentationController? {
        let sheet = ControlledSheetPresentationController(presentedViewController: presented, presenting: presenting)
        self.sheet = sheet
        return sheet
    }
    func animationController(forPresented presented: UIViewController, presenting: UIViewController,
                             source: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
        if holdPresentation { return heldPresentation }
        return SheetTransitionAnimator(presenting: true)
    }
    func animationController(forDismissed dismissed: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
        // A cancelled animator/interaction must never be reused by ordinary Done.
        requestingInteraction ? dismissal : SheetTransitionAnimator(presenting: false)
    }
    func interactionControllerForDismissal(using animator: any UIViewControllerAnimatedTransitioning) -> (any UIViewControllerInteractiveTransitioning)? {
        requestingInteraction ? interaction : nil
    }
}

@MainActor private final class ControlledSheetPresentationController: UIPresentationController {
    private(set) var observedInteraction = false
    private(set) var forwardedWillDismiss = false
    private(set) var completionRegistered = false
    private(set) var observedCancellation = false
    private(set) var forwardedDidDismissCount = 0
    private var currentDismissalIsInteractive = false

    override var shouldRemovePresentersView: Bool { false }
    override var frameOfPresentedViewInContainerView: CGRect {
        guard let bounds = containerView?.bounds else { return .zero }
        return CGRect(x: bounds.minX, y: bounds.minY + bounds.height * 0.4,
                      width: bounds.width, height: bounds.height * 0.6)
    }
    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
    }
    override func dismissalTransitionWillBegin() {
        super.dismissalTransitionWillBegin()
        currentDismissalIsInteractive = false
        guard let transition = presentedViewController.transitionCoordinator, transition.isInteractive else { return }
        currentDismissalIsInteractive = true
        observedInteraction = true
        completionRegistered = transition.animate(alongsideTransition: nil) { [weak self] context in
            self?.observedCancellation = context.isCancelled
        }
        if let delegate {
            forwardedWillDismiss = true
            delegate.presentationControllerWillDismiss?(self)
        }
    }
    override func dismissalTransitionDidEnd(_ completed: Bool) {
        super.dismissalTransitionDidEnd(completed)
        if currentDismissalIsInteractive, completed {
            forwardedDidDismissCount += 1
            delegate?.presentationControllerDidDismiss?(self)
        }
        currentDismissalIsInteractive = false
    }
}

@MainActor private final class SheetTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private let presenting: Bool
    private(set) var started = false
    private(set) var completed = false
    private(set) var wasInteractive = false

    init(presenting: Bool) { self.presenting = presenting; super.init() }
    nonisolated func transitionDuration(using context: (any UIViewControllerContextTransitioning)?) -> TimeInterval { 0.25 }
    func animateTransition(using context: any UIViewControllerContextTransitioning) {
        started = true
        wasInteractive = context.isInteractive
        let key: UITransitionContextViewKey = presenting ? .to : .from
        guard let view = context.view(forKey: key) else { context.completeTransition(false); return }
        if presenting, let destination = context.viewController(forKey: .to) {
            view.frame = context.finalFrame(for: destination)
            context.containerView.addSubview(view)
            view.transform = CGAffineTransform(translationX: 0, y: context.containerView.bounds.height)
        }
        let presenting = presenting
        UIView.animate(withDuration: transitionDuration(using: context), delay: 0, options: .curveLinear) {
            view.transform = presenting ? .identity : CGAffineTransform(translationX: 0, y: context.containerView.bounds.height)
        } completion: { [weak self] _ in
            view.transform = .identity
            context.completeTransition(!context.transitionWasCancelled)
            self?.completed = true
        }
    }
}
