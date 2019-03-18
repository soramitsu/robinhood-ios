import Foundation

// MARK: Trigger Protocol implementation
extension SingleValueProvider: DataProviderTriggerDelegate {
    public func didTrigger() {
        dispatchUpdateCache()
    }
}
