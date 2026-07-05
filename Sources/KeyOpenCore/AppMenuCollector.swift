import ApplicationServices

public struct AppMenuCollector: ShortcutCollector {
    private let pid: pid_t

    public init(pid: pid_t) {
        self.pid = pid
    }

    public func collect() -> [Binding] {
        let app = AXUIElementCreateApplication(pid)
        guard let menuBar = copyElement(app, "AXMenuBar") else { return [] }
        var out: [Binding] = []
        traverse(menuBar, depth: 0, into: &out)
        return out
    }

    private func traverse(_ element: AXUIElement, depth: Int, into out: inout [Binding]) {
        guard depth < 12 else { return } // guard against pathological menu trees
        guard let children = copyChildren(element) else { return }
        for child in children {
            let cmdChar = copyString(child, "AXMenuItemCmdChar")
            let cmdMods = copyInt(child, "AXMenuItemCmdModifiers") ?? 0
            let cmdGlyph = copyInt(child, "AXMenuItemCmdGlyph")
            if let combo = MenuItemDecoder.decode(cmdChar: cmdChar, cmdModifiers: cmdMods, cmdGlyph: cmdGlyph) {
                let title = copyString(child, "AXTitle") ?? cmdChar ?? "?"
                out.append(Binding(combo: combo, action: title, source: .appMenu))
            }
            traverse(child, depth: depth + 1, into: &out)
        }
    }

    // MARK: - AX helpers

    private func copyElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success,
              let value = ref, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    private func copyChildren(_ element: AXUIElement) -> [AXUIElement]? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &ref) == .success
        else { return nil }
        return ref as? [AXUIElement]
    }

    private func copyString(_ element: AXUIElement, _ attribute: String) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success
        else { return nil }
        return ref as? String
    }

    private func copyInt(_ element: AXUIElement, _ attribute: String) -> Int? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success,
              let number = ref as? NSNumber
        else { return nil }
        return number.intValue
    }
}
