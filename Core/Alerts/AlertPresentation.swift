import SwiftUI
import UIKit

/// One alert's UIKit lifetime. The SwiftUI renderer is a native .alert anchored
/// in a tiny hosting child of the actual visible content controller (including XIBs).
@MainActor final class AlertPresentation {
    private let request: AppAlertRequest
    private weak var presenter: UIViewController?
    private weak var root: UIViewController?
    private var anchor: UIViewController?
    private var nativeAlert: UIViewController?
    private var swiftUIState: SwiftUIAlertState?
    private var dismissalTask: Task<Void, Never>?
    private var finishing = false
    private var completion: ((AppAlertAction?) -> Void)?

    init(request: AppAlertRequest, presenter: UIViewController, root: UIViewController,
         completion: @escaping (AppAlertAction?) -> Void) {
        self.request = request; self.presenter = presenter; self.root = root
        self.completion = completion
    }

    func present() {
        guard let presenter else { finish(nil); return }
        switch request.style {
        case .uikit:
            let alert = UIAlertController(title: request.title, message: request.message, preferredStyle: .alert)
            for action in request.actions {
                alert.addAction(UIAlertAction(title: action.title, style: action == .cancel ? .cancel : .default) { [weak self] _ in
                    self?.selected(action)
                })
            }
            nativeAlert = alert
            presenter.present(alert, animated: true)
        case .swiftUI:
            let state = SwiftUIAlertState(request: request) { [weak self] action in self?.selected(action) }
            swiftUIState = state
            let host = UIHostingController(rootView: SwiftUIAlertAnchor(state: state))
            anchor = host
            host.view.backgroundColor = .clear
            host.view.isUserInteractionEnabled = false
            presenter.addChild(host)
            presenter.view.addSubview(host.view)
            host.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                host.view.widthAnchor.constraint(equalToConstant: 1),
                host.view.heightAnchor.constraint(equalToConstant: 1),
                host.view.centerXAnchor.constraint(equalTo: presenter.view.centerXAnchor),
                host.view.centerYAnchor.constraint(equalTo: presenter.view.centerYAnchor)
            ])
            host.didMove(toParent: presenter)
        }
    }

    private func selected(_ action: AppAlertAction) {
        guard !finishing else { return }
        finishing = true
        captureNativeAlert()
        // Both UIKit actions and SwiftUI .alert dismiss themselves after the action.
        // Wait for the actual controller to leave its window before draining navigation.
        waitForDismissal(result: action)
    }

    func setSceneActive(_ active: Bool) {
        swiftUIState?.setSceneActive(active)
    }

    func cancel() {
        if finishing { return }
        finishing = true
        captureNativeAlert()
        swiftUIState?.cancelled = true
        swiftUIState?.visible = false
        if request.style == .uikit, let alert = nativeAlert {
            if alert.isBeingPresented, let transition = alert.transitionCoordinator {
                let registered = transition.animate(alongsideTransition: nil) { [weak alert] _ in
                    alert?.dismiss(animated: false)
                }
                if !registered { alert.dismiss(animated: false) }
            } else { alert.dismiss(animated: false) }
        }
        waitForDismissal(result: nil)
    }

    private func captureNativeAlert() {
        guard nativeAlert == nil, let root else { return }
        let visible = Self.visibleController(from: root)
        if visible !== presenter && visible !== anchor { nativeAlert = visible }
    }

    private func waitForDismissal(result: AppAlertAction?) {
        dismissalTask = Task { @MainActor [weak self] in
            // SwiftUI schedules its native dismissal after its action closure returns.
            await Task.yield()
            while !Task.isCancelled {
                guard let gone = self?.finishIfDismissed(result: result) else { return }
                if gone { return }
                do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
            }
        }
    }

    private func finishIfDismissed(result: AppAlertAction?) -> Bool {
        if nativeAlert?.viewIfLoaded?.window != nil { return false }
        finish(result)
        return true
    }

    private func finish(_ result: AppAlertAction?) {
        anchor?.willMove(toParent: nil)
        anchor?.view.removeFromSuperview()
        anchor?.removeFromParent()
        anchor = nil; swiftUIState = nil; nativeAlert = nil
        let callback = completion
        completion = nil
        callback?(result)
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
        // The application shell has the navigation controller and diagnostics as siblings.
        if let nav = controller.children.first(where: { $0 is UINavigationController }) {
            return visibleController(from: nav)
        }
        return controller
    }

    deinit { dismissalTask?.cancel() }
}

@MainActor private final class SwiftUIAlertState: ObservableObject {
    let request: AppAlertRequest
    let select: (AppAlertAction) -> Void
    @Published var visible = false
    var cancelled = false
    private var started = false
    private var sceneIsActive = true
    private var appeared = false
    init(request: AppAlertRequest, select: @escaping (AppAlertAction) -> Void) {
        self.request = request; self.select = select
    }
    func didAppear() { appeared = true; showIfReady() }
    func setSceneActive(_ active: Bool) { sceneIsActive = active; showIfReady() }
    private func showIfReady() {
        guard appeared, sceneIsActive, !started, !cancelled else { return }
        started = true; visible = true
    }
}

private struct SwiftUIAlertAnchor: View {
    @ObservedObject var state: SwiftUIAlertState
    var body: some View {
        Color.clear
            .onAppear { state.didAppear() }
            .alert(state.request.title, isPresented: $state.visible) {
                ForEach(state.request.actions, id: \.self) { action in
                    Button(action.title, role: action == .cancel ? .cancel : nil) { state.select(action) }
                }
            } message: {
                Text(state.request.message)
            }
    }
}
