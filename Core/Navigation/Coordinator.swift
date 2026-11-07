import Foundation

@MainActor protocol Coordinator: AnyObject {
    var id: UUID { get }
    func start()
    func stop()
}
