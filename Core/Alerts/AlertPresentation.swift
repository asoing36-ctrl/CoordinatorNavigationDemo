import SwiftUI
import UIKit

/// Owns exactly one presentation subtree; it never dismisses the feature below it.
@MainActor final class AlertPresentation {
    private enum Phase { case idle, presenting, visible, dismissing, finished }
    private enum Outcome { case selected(AppAlertAction), cancelled }

    private let request: AppAlertRequest
    private weak var presenter: UIViewController?
    private var controller: UIViewController?
    private var swiftUIState: SwiftUIAlertState?
    private var phase: Phase = .idle
    private var outcome: Outcome?
    private var sceneIsActive = true
    private var completion: ((AppAlertAction?) -> Void)?

    init(request: AppAlertRequest, presenter: UIViewController,
         completion: @escaping (AppAlertAction?) -> Void) {
        self.request = request
        self.presenter = presenter
        self.completion = completion
    }

    func present() {
        guard phase == .idle else { return }
        guard let presenter, presenter.viewIfLoaded?.window != nil,
              presenter.presentedViewController == nil else {
            outcome = .cancelled
            finish()
            return
        }
        let owned: UIViewController
        switch request.style {
        case .uikit:
            let alert = UIAlertController(title: request.title, message: request.message, preferredStyle: .alert)
            for action in request.actions {
                alert.addAction(UIAlertAction(title: action.title, style: action == .cancel ? .cancel : .default) { [weak self] _ in
                    self?.selected(action)
                })
            }
            owned = alert
        case .swiftUI:
            let state = SwiftUIAlertState(request: request) { [weak self] action in self?.selected(action) }
            swiftUIState = state
            let host = UIHostingController(rootView: SwiftUIAlertContent(state: state))
            host.modalPresentationStyle = .overFullScreen
            host.isModalInPresentation = true
            host.view.backgroundColor = .clear
            host.view.isOpaque = false
            // This is an owned modal, not a subview inserted into another hosting view.
            owned = host
        }
        controller = owned
        phase = .presenting
        presenter.present(owned, animated: request.style == .uikit) { [weak self] in
            guard let self, self.phase == .presenting else { return }
            self.phase = .visible
            if self.outcome != nil { self.scheduleDismissal() }
            else { self.scheduleSwiftUIAppearance() }
        }
        // A rejected UIKit presentation does not call completion. Do not strand the queue.
        if phase == .presenting, owned.presentingViewController == nil, !owned.isBeingPresented {
            outcome = .cancelled
            finish()
        }
    }

    func setSceneActive(_ active: Bool) {
        sceneIsActive = active
        if active { scheduleSwiftUIAppearance() }
    }

    func cancel() {
        guard phase != .finished else { return }
        // Cancellation also suppresses an action already waiting for its dismissal completion.
        outcome = .cancelled
        if phase == .idle { finish() }
        else { scheduleDismissal() }
    }

    private func scheduleSwiftUIAppearance() {
        // UIKit's presentation callback, followed by a main-queue turn, is outside the
        // SwiftUI view-update/onAppear callback. Recheck scene/cancellation at execution.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.phase == .visible, self.outcome == nil, self.sceneIsActive else { return }
            self.swiftUIState?.show()
        }
    }

    private func selected(_ action: AppAlertAction) {
        guard phase == .visible || phase == .presenting,
              outcome == nil, request.actions.contains(action) else { return }
        outcome = .selected(action)
        scheduleDismissal()
    }

    private func scheduleDismissal() {
        // Cancellation during presentation waits for that presentation's real completion.
        guard phase == .visible else { return }
        phase = .dismissing
        // Native alert actions start their automatic dismissal after the handler returns.
        DispatchQueue.main.async { [weak self] in self?.dismissOwnedController() }
    }

    private func dismissOwnedController() {
        guard phase == .dismissing, let owned = controller else { return }
        var top = owned
        while let child = top.presentedViewController { top = child }
        if top.isBeingPresented || top.isBeingDismissed || owned.isBeingDismissed,
           let transition = top.transitionCoordinator ?? owned.transitionCoordinator {
            let registered = transition.animate(alongsideTransition: nil) { [weak self] _ in
                // UIKit may still expose the finishing coordinator inside its callback.
                DispatchQueue.main.async { [weak self] in self?.dismissOwnedController() }
            }
            if registered { return }
        }
        guard let owner = owned.presentingViewController,
              owner.presentedViewController === owned else {
            // Already dismissed/detached. This exact owned presentation is gone.
            finish()
            return
        }
        // Dismiss ONLY our subtree, including SwiftUI's native alert if it still exists.
        // The owner's existing feature/modal is below this child and remains untouched.
        owner.dismiss(animated: request.style == .uikit) { [weak self] in self?.finish() }
    }

    private func finish() {
        guard phase != .finished else { return }
        phase = .finished
        let action: AppAlertAction?
        if case .selected(let selected)? = outcome { action = selected }
        else { action = nil }
        controller = nil
        swiftUIState = nil
        let callback = completion
        completion = nil
        callback?(action)
    }

    static func visibleController(from controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController {
            return visibleController(from: presented)
        }
        if let nav = controller as? UINavigationController, let top = nav.visibleViewController {
            return visibleController(from: top)
        }
        if let tab = controller as? UITabBarController, let selected = tab.selectedViewController {
            return visibleController(from: selected)
        }
        // The application shell has navigation and diagnostics as siblings.
        if let nav = controller.children.first(where: { $0 is UINavigationController }) {
            return visibleController(from: nav)
        }
        return controller
    }
}

@MainActor private final class SwiftUIAlertState: ObservableObject {
    let request: AppAlertRequest
    let select: (AppAlertAction) -> Void
    @Published private(set) var ready = false
    private var started = false

    init(request: AppAlertRequest, select: @escaping (AppAlertAction) -> Void) {
        self.request = request
        self.select = select
    }
    func show() {
        guard !started else { return }
        started = true
        ready = true
    }
}

private struct SwiftUIAlertContent: View {
    @ObservedObject var state: SwiftUIAlertState
    @State private var visible = false
    init(state: SwiftUIAlertState) { self.state = state }
    var body: some View {
        Color.clear
            // SwiftUI resets this binding during its dismissal update. Keep that
            // write in local State rather than publishing objectWillChange there.
            .onChange(of: state.ready, initial: true) { _, ready in
                if ready { visible = true }
            }
            .alert(state.request.title, isPresented: $visible) {
                ForEach(state.request.actions, id: \.self) { action in
                    Button(action.title, role: action == .cancel ? .cancel : nil) { state.select(action) }
                }
            } message: {
                Text(state.request.message)
            }
    }
}
