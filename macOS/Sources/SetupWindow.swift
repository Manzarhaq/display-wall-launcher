import AppKit

final class SetupWindow: NSWindowController {
    let urlField = NSTextField(string: "")
    let status = NSTextField(wrappingLabelWithString: "Ready. Choose displays, or try a single-screen preview.")
    private let displays = NSStackView()
    private var choices: [(DisplayChoice, NSButton)] = []
    var onPresent: (([DisplayChoice], String) -> Void)?
    var onPreview: ((String) -> Void)?

    init(url: String) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Display Wall Launcher"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        let root = NSStackView()
        root.orientation = .vertical; root.alignment = .leading; root.spacing = 16
        root.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 28),
            root.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -28),
            root.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 26)
        ])
        let heading = NSTextField(labelWithString: "Display Wall Launcher")
        heading.font = .systemFont(ofSize: 26, weight: .semibold)
        root.addArrangedSubview(heading)
        root.addArrangedSubview(NSTextField(wrappingLabelWithString: "One continuous web canvas across your selected displays."))
        root.addArrangedSubview(NSTextField(labelWithString: "Web address"))
        urlField.stringValue = url; urlField.placeholderString = "https://…"
        urlField.setAccessibilityLabel("Web address")
        root.addArrangedSubview(urlField)
        urlField.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        root.addArrangedSubview(NSTextField(labelWithString: "Presentation displays"))
        displays.orientation = .vertical; displays.alignment = .leading; displays.spacing = 8
        root.addArrangedSubview(displays)
        let note = NSTextField(wrappingLabelWithString: "For two screens: use extended displays, arranged side by side at equal scaled heights. Turn OFF ‘Displays have separate Spaces’, then log out and back in. No display settings are changed by this app.")
        note.textColor = .secondaryLabelColor
        root.addArrangedSubview(note)
        let actions = NSStackView()
        actions.spacing = 12
        let preview = NSButton(title: "Preview on this screen", target: self, action: #selector(preview))
        let present = NSButton(title: "Present", target: self, action: #selector(present))
        present.bezelStyle = .rounded; present.keyEquivalent = "\r"
        actions.addArrangedSubview(preview); actions.addArrangedSubview(present)
        root.addArrangedSubview(actions)
        root.addArrangedSubview(NSTextField(labelWithString: "Escape or ⌘. returns to setup · ⌘R reloads · ⌘Q quits"))
        status.textColor = .secondaryLabelColor
        root.addArrangedSubview(status)
        status.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        note.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        refreshDisplays()
        window.center()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func refreshDisplays() {
        let selected = Set(choices.filter { $0.1.state == .on }.map { $0.0.id })
        for view in displays.arrangedSubviews { displays.removeArrangedSubview(view); view.removeFromSuperview() }
        let stored = Set((UserDefaults(suiteName: "io.github.displaywalllauncher")!.array(forKey: "displayIDs") as? [Int] ?? []).map { UInt32($0) })
        choices = DisplayChoice.available.map { choice in
            let button = NSButton(checkboxWithTitle: choice.label, target: nil, action: nil)
            button.state = (selected.isEmpty ? stored : selected).contains(choice.id) ? .on : .off
            displays.addArrangedSubview(button)
            return (choice, button)
        }
        if choices.count == 1 { choices[0].1.state = .on }
        let height = max(560, 480 + choices.count * 28)
        window?.setContentSize(NSSize(width: 760, height: height))
    }
    @objc private func present() { onPresent?(choices.filter { $0.1.state == .on }.map { $0.0 }, urlField.stringValue) }
    @objc private func preview() { onPreview?(urlField.stringValue) }
}
