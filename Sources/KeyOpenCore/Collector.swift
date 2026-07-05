public protocol ShortcutCollector: Sendable {
    func collect() -> [Binding]
}
