import UIKit

/// A separate bounded informational channel. It owns no navigation state.
@MainActor final class SnackbarPresenter {
    private let queue = AppAlertQueue(maximumPendingRequests: 5) // Four waiting global notices, plus active.
    private let clock: any NoticeClock
    private let sourceWindow: () -> UIWindow?
    private var window: SnackbarWindow?
    private var timer: ForegroundNoticeTimer?
    private var sceneIsActive = false
    private var blocked = false
    private var finishing = false

    init(clock: any NoticeClock, sourceWindow: @escaping () -> UIWindow?) {
        self.clock = clock; self.sourceWindow = sourceWindow
    }
    @discardableResult func show(_ request: AppAlertRequest,
        completion: @escaping @MainActor (AppAlertAction) -> Void) -> AlertAdmission {
        let result = queue.enqueue(request, completion: completion)
        refresh()
        return result
    }
    func update(sceneIsActive: Bool, blocked: Bool) {
        self.sceneIsActive = sceneIsActive; self.blocked = blocked
        refresh()
    }
    func cancelAll() {
        queue.cancelAll()
        removeWindow()
    }
    private func refresh() {
        guard !finishing else { return }
        queue.sceneIsActive = sceneIsActive && !blocked
        guard queue.sceneIsActive, let source = sourceWindow(), let scene = source.windowScene else {
            timer?.pause(); window?.isHidden = true
            return
        }
        if let window {
            window.isHidden = false
            resumeVisibleNotice(id: queue.current?.id)
            return
        }
        guard let request = queue.beginNext() else { return }
        let id = request.id
        let controller = SnackbarViewController(request: request,
            dismiss: { [weak self] in self?.finish(id: id, action: .ok) },
            didAppear: { [weak self] in self?.resumeVisibleNotice(id: id) })
        let overlay = SnackbarWindow(windowScene: scene)
        overlay.windowLevel = .normal + 1
        overlay.backgroundColor = .clear
        overlay.rootViewController = controller
        window = overlay
        if let duration = request.dismissAfter {
            timer = ForegroundNoticeTimer(duration: duration, clock: clock) { [weak self] in
                self?.finish(id: id, action: nil)
            }
        }
        // Never makeKeyAndVisible: the application retains keyboard/focus ownership.
        overlay.isHidden = false
    }
    private func resumeVisibleNotice(id: UUID?) {
        guard let id, queue.current?.id == id, sceneIsActive, !blocked,
              let window, !window.isHidden,
              let controller = window.rootViewController as? SnackbarViewController,
              controller.hasAppeared, controller.viewIfLoaded?.window != nil else { return }
        timer?.resume()
    }
    private func finish(id: UUID, action: AppAlertAction?) {
        guard queue.current?.id == id else { return }
        finishing = true
        removeWindow()
        // Clear queue ownership before callbacks can submit more work.
        if let action { queue.complete(id: id, action: action) }
        else { queue.cancel(id: id) }
        finishing = false
        refresh()
    }
    private func removeWindow() {
        timer?.cancel(); timer = nil
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
    }
    deinit {
        // Explicit reset/stop cleans up synchronously. The fallback must also
        // respect UIKit isolation if the owner is released on another executor.
        if let window {
            Task { @MainActor in window.isHidden = true; window.rootViewController = nil }
        }
    }
}

/// Only the banner accepts touches; everything else reaches the existing app window.
@MainActor private final class SnackbarWindow: UIWindow {
    override var canBecomeKey: Bool { false }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let controller = rootViewController as? SnackbarViewController,
              controller.bannerContains(point: point, in: self) else { return nil }
        return super.hitTest(point, with: event)
    }
}

@MainActor private final class SnackbarViewController: UIViewController {
    private let request: AppAlertRequest
    private let dismissNotice: () -> Void
    private let appeared: () -> Void
    private let banner = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private(set) var hasAppeared = false

    init(request: AppAlertRequest, dismiss: @escaping () -> Void, didAppear: @escaping () -> Void) {
        self.request = request; dismissNotice = dismiss; appeared = didAppear
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("Use injected notice") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.accessibilityIdentifier = "snackbarOverlay"
        banner.accessibilityIdentifier = "snackbar"
        banner.layer.cornerRadius = 16; banner.clipsToBounds = true
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)
        let title = UILabel()
        title.text = request.title; title.font = .preferredFont(forTextStyle: .headline)
        title.adjustsFontForContentSizeCategory = true; title.numberOfLines = 0
        title.accessibilityIdentifier = "snackbarTitle"
        let message = UILabel()
        message.text = request.message; message.font = .preferredFont(forTextStyle: .subheadline)
        message.adjustsFontForContentSizeCategory = true; message.numberOfLines = 0
        message.accessibilityIdentifier = "snackbarMessage"
        let close = UIButton(type: .system)
        close.setTitle("Dismiss", for: .normal)
        close.titleLabel?.font = .preferredFont(forTextStyle: .callout)
        close.titleLabel?.adjustsFontForContentSizeCategory = true
        close.accessibilityIdentifier = "dismissSnackbar"
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        let content = UIStackView(arrangedSubviews: [title, message, close])
        content.axis = .vertical; content.spacing = 6
        content.translatesAutoresizingMaskIntoConstraints = false
        banner.contentView.addSubview(content)
        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            banner.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            banner.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            banner.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            content.leadingAnchor.constraint(equalTo: banner.contentView.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: banner.contentView.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: banner.contentView.topAnchor, constant: 12),
            content.bottomAnchor.constraint(equalTo: banner.contentView.bottomAnchor, constant: -8),
            close.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        hasAppeared = true
        appeared()
    }
    func bannerContains(point: CGPoint, in window: UIWindow) -> Bool {
        banner.bounds.contains(banner.convert(point, from: window))
    }
    @objc private func closeTapped() { dismissNotice() }
}
