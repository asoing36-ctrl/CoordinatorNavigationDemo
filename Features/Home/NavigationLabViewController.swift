import UIKit

@MainActor final class NavigationLabViewController: UIViewController {
    @IBOutlet private(set) weak var swiftUIButton: UIButton!
    @IBOutlet private weak var uikitButton: UIButton!
    @IBOutlet private(set) weak var dismissButton: UIButton!
    @IBOutlet private weak var presentSheetButton: UIButton!
    private let openSwiftUI: () -> Void
    private let openUIKit: () -> Void
    private let presentSwiftUIAction: (() -> Void)?
    private let dismissAction: (() -> Void)?
    init(openSwiftUI: @escaping () -> Void, openUIKit: @escaping () -> Void,
         presentSwiftUI: (() -> Void)? = nil, dismiss: (() -> Void)? = nil) {
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
        view.accessibilityIdentifier = "labScreen"
    }
    @IBAction private func swiftUITapped(_ sender: UIButton) { openSwiftUI() }
    @IBAction private func uikitTapped(_ sender: UIButton) { openUIKit() }
    @IBAction private func presentSheetTapped(_ sender: UIButton) { presentSwiftUIAction?() }
    @IBAction private func dismissTapped(_ sender: UIButton) { dismissAction?() }
}
