import UIKit
import Combine

@MainActor final class AssociatePhoneViewController: UIViewController {
    @IBOutlet private(set) weak var associateButton: UIButton!
    @IBOutlet private(set) weak var skipButton: UIButton!
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var errorLabel: UILabel!
    @IBOutlet private weak var failureSwitch: UISwitch!
    @IBOutlet private weak var spinner: UIActivityIndicatorView!
    private let model: PhoneViewModel
    private let associate: (Bool) -> Void
    private let skip: () -> Void
    private var observation: AnyCancellable?
    init(model: PhoneViewModel, associate: @escaping (Bool) -> Void, skip: @escaping () -> Void) {
        self.model = model; self.associate = associate; self.skip = skip
        super.init(nibName: "AssociatePhoneViewController", bundle: .main)
    }
    required init?(coder: NSCoder) { fatalError("Use dependency-injected initializer") }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Associate Phone"
        navigationItem.hidesBackButton = true
        view.accessibilityIdentifier = "phoneScreen"
        associateButton.accessibilityIdentifier = "associatePhone"
        skipButton.accessibilityIdentifier = "skipPhone"
        failureSwitch.accessibilityIdentifier = "phoneFailure"
        errorLabel.accessibilityIdentifier = "phoneError"
        // Observable state is main-actor isolated. Delivery remains on the publishing actor.
        observation = model.objectWillChange.sink { [weak self] in
            Task { @MainActor [weak self] in self?.render() }
        }
        render()
    }
    private func render() {
        statusLabel.text = model.status
        errorLabel.text = model.error
        associateButton.isEnabled = !model.loading
        skipButton.isEnabled = !model.loading
        failureSwitch.isEnabled = !model.loading
        if model.loading { spinner.startAnimating() } else { spinner.stopAnimating() }
    }
    @IBAction private func associateTapped(_ sender: UIButton) { associate(failureSwitch.isOn) }
    @IBAction private func skipTapped(_ sender: UIButton) { skip() }
}
