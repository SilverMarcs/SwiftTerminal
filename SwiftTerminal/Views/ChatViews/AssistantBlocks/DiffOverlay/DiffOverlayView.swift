import AppKit

final class DiffOverlayView: NSView {
    private let headerContainer = NSView()
    private let pathIcon = NSImageView()
    private let pathLabel = NSTextField(labelWithString: "")
    private let statsLabel = NSTextField(labelWithString: "")
    private let openButton = NSButton()

    private let borderView = NSView()

    private let diffScrollView = HorizontalOnlyScrollView()
    private let diffTextView = SharedDiffTextView()

    private var currentSpec: DiffOverlaySpec?

    var onOpenFile: ((String) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 1

        setupHeader()
        setupDiffArea()
        applyAppearanceColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func menu(for event: NSEvent) -> NSMenu? {
        markdownAncestorMenu(from: self)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearanceColors()
    }

    private func applyAppearanceColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.quaternarySystemFill.cgColor
            layer?.borderColor = NSColor.separatorColor.cgColor
            borderView.layer?.backgroundColor = NSColor.separatorColor.cgColor
        }
    }

    private func setupHeader() {
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        pathIcon.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        openButton.translatesAutoresizingMaskIntoConstraints = false
        borderView.translatesAutoresizingMaskIntoConstraints = false

        pathIcon.image = NSImage(systemSymbolName: "pencil.line", accessibilityDescription: nil)
        pathIcon.contentTintColor = .secondaryLabelColor
        pathIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)

        pathLabel.font = .systemFont(ofSize: 12, weight: .medium)
        pathLabel.textColor = .labelColor
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.maximumNumberOfLines = 1
        pathLabel.cell?.wraps = false

        statsLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        statsLabel.textColor = .secondaryLabelColor

        openButton.bezelStyle = .accessoryBarAction
        openButton.isBordered = false
        openButton.image = NSImage(systemSymbolName: "arrow.up.forward.square", accessibilityDescription: "Open file")
        openButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        openButton.contentTintColor = .secondaryLabelColor
        openButton.toolTip = "Open file"
        openButton.target = self
        openButton.action = #selector(openButtonClicked(_:))
        openButton.setButtonType(.momentaryChange)

        borderView.wantsLayer = true

        headerContainer.addSubview(pathIcon)
        headerContainer.addSubview(pathLabel)
        headerContainer.addSubview(statsLabel)
        headerContainer.addSubview(openButton)

        addSubview(headerContainer)
        addSubview(borderView)

        NSLayoutConstraint.activate([
            headerContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerContainer.topAnchor.constraint(equalTo: topAnchor),
            headerContainer.heightAnchor.constraint(equalToConstant: 24),

            pathIcon.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 10),
            pathIcon.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),

            pathLabel.leadingAnchor.constraint(equalTo: pathIcon.trailingAnchor, constant: 6),
            pathLabel.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),

            statsLabel.leadingAnchor.constraint(equalTo: pathLabel.trailingAnchor, constant: 8),
            statsLabel.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),

            openButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -8),
            openButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            openButton.widthAnchor.constraint(equalToConstant: 18),
            openButton.heightAnchor.constraint(equalToConstant: 18),

            borderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            borderView.trailingAnchor.constraint(equalTo: trailingAnchor),
            borderView.topAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            borderView.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    @objc private func openButtonClicked(_ sender: Any?) {
        guard let spec = currentSpec else { return }
        onOpenFile?(spec.path)
    }

    private func setupDiffArea() {
        diffScrollView.translatesAutoresizingMaskIntoConstraints = false
        diffScrollView.hasVerticalScroller = false
        diffScrollView.hasHorizontalScroller = true
        diffScrollView.autohidesScrollers = true
        diffScrollView.verticalScrollElasticity = .none
        diffScrollView.drawsBackground = false
        diffScrollView.borderType = .noBorder

        diffScrollView.documentView = diffTextView
        addSubview(diffScrollView)

        NSLayoutConstraint.activate([
            diffScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            diffScrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            diffScrollView.topAnchor.constraint(equalTo: borderView.bottomAnchor, constant: 4),
            diffScrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    func configure(spec: DiffOverlaySpec) {
        currentSpec = spec

        pathLabel.stringValue = (spec.path as NSString).lastPathComponent

        let lines = UnifiedDiff.lines(oldText: spec.oldText, newText: spec.newText)

        let added = lines.filter { $0.kind == .added }.count
        let removed = lines.filter { $0.kind == .removed }.count
        let statsText = NSMutableAttributedString()
        if added > 0 {
            statsText.append(NSAttributedString(
                string: "+\(added)",
                attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: NSColor.systemGreen
                ]
            ))
        }
        if added > 0 && removed > 0 {
            statsText.append(NSAttributedString(string: " "))
        }
        if removed > 0 {
            statsText.append(NSAttributedString(
                string: "-\(removed)",
                attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: NSColor.systemRed
                ]
            ))
        }
        statsLabel.attributedStringValue = statsText

        let ext = (spec.path as NSString).pathExtension
        diffTextView.configure(
            lines: lines,
            fileExtension: ext,
            layout: .popover(wrapsLines: false),
            width: bounds.width
        )
    }

    func refreshAppearance() {
        guard let spec = currentSpec else { return }
        configure(spec: spec)
    }
}
