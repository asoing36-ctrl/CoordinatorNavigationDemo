import UIKit

@MainActor final class NavigationLabViewController: UIViewController {
    @IBOutlet private(set) weak var swiftUIButton: UIButton!
    @IBOutlet private weak var uikitButton: UIButton!
    @IBOutlet private(set) weak var dismissButton: UIButton!
    @IBOutlet private weak var presentSheetButton: UIButton!
    @IBOutlet private weak var uikitAlertButton: UIButton!
    @IBOutlet private weak var swiftUIAlertButton: UIButton!
    @IBOutlet private weak var timedUIKitButton: UIButton!
    @IBOutlet private weak var timedSwiftUIButton: UIButton!
    @IBOutlet private weak var timedSnackbarButton: UIButton!
    @IBOutlet private weak var persistentSnackbarButton: UIButton!
    private let showAlert: ((AppAlertStyle) -> Void)?
    private let showNotice: ((AppAlertRequest) -> Void)?
    private let openSwiftUI: () -> Void
    private let openUIKit: () -> Void
    private let presentSwiftUIAction: (() -> Void)?
    private let dismissAction: (() -> Void)?
    init(openSwiftUI: @escaping () -> Void, openUIKit: @escaping () -> Void,
         presentSwiftUI: (() -> Void)? = nil, dismiss: (() -> Void)? = nil, showAlert: ((AppAlertStyle) -> Void)? = nil,
         showNotice: ((AppAlertRequest) -> Void)? = nil) {
        self.showAlert = showAlert
        self.showNotice = showNotice
        self.openSwiftUI = openSwiftUI; self.openUIKit = openUIKit
        presentSwiftUIAction = presentSwiftUI; dismissAction = dismiss
        super.init(nibName: "NavigationLabViewController", bundle: .main)
    }
    required init?(coder: NSCoder) { fatalError("Use dependency-injected initializer") }
    override func viewDidLoad() {
        super.viewDidLoad()
        swiftUIButton.accessibilityIdentifier = "labOpenSwiftUI"
        uikitButton.accessibilityIdentifier = "labOpenUIKit"
        presentSheetButton.accessibilityIdentifier = "labPresentSwiftUI"
        dismissButton.accessibilityIdentifier = "dismissUIKitModal"
        dismissButton.isHidden = dismissAction == nil
        presentSheetButton.isHidden = presentSwiftUIAction == nil
        uikitAlertButton.accessibilityIdentifier = "showUIKitAlert"
        swiftUIAlertButton.accessibilityIdentifier = "showSwiftUIAlert"
        uikitAlertButton.isHidden = showAlert == nil
        swiftUIAlertButton.isHidden = showAlert == nil
        for (button, identifier) in [(timedUIKitButton, "showTimedUIKitAlert"), (timedSwiftUIButton, "showTimedSwiftUIAlert"),
            (timedSnackbarButton, "showTimedSnackbar"), (persistentSnackbarButton, "showPersistentSnackbar")] {
            button?.accessibilityIdentifier = identifier
            button?.isHidden = showNotice == nil
        }
        view.accessibilityIdentifier = "labScreen"
    }
    @IBAction private func uikitAlertTapped(_ sender: UIButton) { showAlert?(.uikit) }
    @IBAction private func swiftUIAlertTapped(_ sender: UIButton) { showAlert?(.swiftUI) }
    @IBAction private func timedUIKitTapped(_ sender: UIButton) { showNotice?(.timedDemo(style: .uikit)) }
    @IBAction private func timedSwiftUITapped(_ sender: UIButton) { showNotice?(.timedDemo(style: .swiftUI)) }
    @IBAction private func timedSnackbarTapped(_ sender: UIButton) { showNotice?(.snackbarDemo(timed: true)) }
    @IBAction private func persistentSnackbarTapped(_ sender: UIButton) { showNotice?(.snackbarDemo(timed: false)) }
    @IBAction private func swiftUITapped(_ sender: UIButton) { openSwiftUI() }
    @IBAction private func uikitTapped(_ sender: UIButton) { openUIKit() }
    @IBAction private func presentSheetTapped(_ sender: UIButton) { presentSwiftUIAction?() }
    @IBAction private func dismissTapped(_ sender: UIButton) { dismissAction?() }
}
