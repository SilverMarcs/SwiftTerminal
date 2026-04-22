import AppKit

// MARK: - Text view with tool-call hit testing

final class AssistantBlocksTextView: NSTextView {
    let blocksTextStorage = NSTextStorage()
    let blocksLayoutManager = MarkdownLayoutManager()
    let blocksTextContainer = NSTextContainer()

    var onToolCallClick: ((Int, NSRect) -> Void)?

    init() {
        blocksLayoutManager.delegate = blocksLayoutManager
        blocksLayoutManager.addTextContainer(blocksTextContainer)
        blocksTextStorage.addLayoutManager(blocksLayoutManager)
        super.init(frame: .zero, textContainer: blocksTextContainer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        markdownAncestorMenu(from: self)
    }

    override func mouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        let origin = textContainerOrigin
        let containerPoint = NSPoint(x: localPoint.x - origin.x, y: localPoint.y - origin.y)
        let container = blocksTextContainer

        guard blocksLayoutManager.numberOfGlyphs > 0 else {
            super.mouseDown(with: event)
            return
        }
        let glyphIndex = blocksLayoutManager.glyphIndex(for: containerPoint, in: container)
        guard glyphIndex < blocksLayoutManager.numberOfGlyphs else {
            super.mouseDown(with: event)
            return
        }

        let charIndex = blocksLayoutManager.characterIndexForGlyph(at: glyphIndex)
        guard charIndex < blocksTextStorage.length else {
            super.mouseDown(with: event)
            return
        }

        var rangeOfAttribute = NSRange()
        let groupID = blocksTextStorage.attribute(
            .assistantToolCallGroupID,
            at: charIndex,
            longestEffectiveRange: &rangeOfAttribute,
            in: NSRange(location: 0, length: blocksTextStorage.length)
        ) as? Int

        if let groupID {
            let glyphRange = blocksLayoutManager.glyphRange(forCharacterRange: rangeOfAttribute, actualCharacterRange: nil)
            let boundingRect = blocksLayoutManager.boundingRect(forGlyphRange: glyphRange, in: container)
            if boundingRect.contains(containerPoint) {
                let rectInTextView = boundingRect.offsetBy(dx: origin.x, dy: origin.y)
                onToolCallClick?(groupID, rectInTextView)
                return
            }
        }

        super.mouseDown(with: event)
    }

    override func resetCursorRects() {
        super.resetCursorRects()

        guard blocksTextStorage.length > 0 else { return }
        let fullRange = NSRange(location: 0, length: blocksTextStorage.length)
        blocksTextStorage.enumerateAttribute(.assistantToolCallGroupID, in: fullRange) { value, range, _ in
            guard value != nil else { return }
            let glyphRange = blocksLayoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let rect = blocksLayoutManager.boundingRect(forGlyphRange: glyphRange, in: blocksTextContainer)
            let converted = rect.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
            addCursorRect(converted, cursor: .pointingHand)
        }
    }
}

// MARK: - Container view

final class AssistantBlocksContainerView: NSView {
    private enum Layout {
        static let copyButtonInset: CGFloat = 4
        static let copyButtonSize: CGFloat = 23
    }

    private let textView = AssistantBlocksTextView()
    private var widthConstraint: NSLayoutConstraint?

    private var currentWidth: CGFloat = 0
    private var lastReportedHeight: CGFloat = 0
    private var lastMeasuredSize: CGSize = .zero
    private var currentDocument: AssistantBlocksDocument?
    private var currentThemeName: String?
    private var needsMeasurement = false
    private var hasAppliedDocument = false

    // Code block copy buttons
    private var codeBlockButtons: [Int: NSButton] = [:]
    private var cachedCodeBlockFrames: [(codeBlock: MarkdownCodeBlock, frame: NSRect)] = []
    private var hoveredCodeBlockID: Int?
    private var trackingArea: NSTrackingArea?

    // Diff overlays
    private var diffOverlayViews: [Int: DiffOverlayView] = [:]

    // Tool call popover
    private var toolCallPopover: NSPopover?

    var onHeightChange: ((CGFloat) -> Void)?
    var onThemeChange: ((String) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        textView.drawsBackground = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.importsGraphics = false
        textView.textContainerInset = .zero
        textView.blocksTextContainer.lineFragmentPadding = 0
        textView.blocksTextContainer.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.onToolCallClick = { [weak self] groupID, rect in
            self?.showToolCallPopover(groupID: groupID, anchorRect: rect)
        }

        addSubview(textView)

        let wc = textView.widthAnchor.constraint(equalToConstant: 0)
        widthConstraint = wc
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),
            wc
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()

        let themeName = colorSchemeThemeName
        guard currentThemeName != themeName else { return }
        currentThemeName = themeName
        textView.needsDisplay = true
        for view in diffOverlayViews.values {
            view.refreshAppearance()
        }
        onThemeChange?(themeName)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateHoveredCodeBlock(for: event)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        hoveredCodeBlockID = nil
        updateCopyButtonVisibility()
    }

    override func layout() {
        super.layout()
        let width = bounds.width > 0 ? bounds.width : currentWidth
        guard width > 0 else { return }

        recalculateIfNeeded(for: width, reportHeight: true)
        layoutCodeBlockButtons()
        layoutDiffOverlays()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: lastMeasuredSize.width, height: lastMeasuredSize.height)
    }

    var activeThemeName: String {
        currentThemeName ?? colorSchemeThemeName
    }

    func apply(document: AssistantBlocksDocument) {
        hasAppliedDocument = true
        currentThemeName = colorSchemeThemeName
        currentDocument = document

        textView.blocksLayoutManager.codeBlocks = document.codeBlocks
        textView.blocksLayoutManager.quoteBlocks = document.quoteBlocks
        textView.blocksLayoutManager.tableBlocks = document.tableBlocks
        textView.blocksLayoutManager.hasThematicBreaks = document.hasThematicBreaks
        textView.blocksTextStorage.setAttributedString(document.attributedString)

        syncCodeBlockButtons(with: document.codeBlocks)
        syncDiffOverlays(with: document.diffOverlays)

        needsMeasurement = true
        needsLayout = true
        invalidateIntrinsicContentSize()
        recalculateIfNeeded(for: currentWidth, reportHeight: true)
    }

    func measuredSize(for width: CGFloat) -> CGSize {
        recalculateIfNeeded(for: width, reportHeight: false)
        return lastMeasuredSize
    }

    // MARK: - Measurement

    private func recalculateIfNeeded(for width: CGFloat, reportHeight: Bool) {
        let resolvedWidth = ceil(width)
        guard resolvedWidth > 0 else { return }

        currentWidth = resolvedWidth

        guard needsMeasurement || lastMeasuredSize.width != resolvedWidth else {
            if reportHeight { reportHeightIfNeeded(lastMeasuredSize.height) }
            return
        }

        widthConstraint?.constant = resolvedWidth
        let measuredHeight = measureHeight()
        lastMeasuredSize = CGSize(width: resolvedWidth, height: measuredHeight)
        needsMeasurement = false

        if reportHeight { reportHeightIfNeeded(measuredHeight) }
    }

    private func measureHeight() -> CGFloat {
        guard currentWidth > 0 else { return 0 }
        textView.frame.size.width = currentWidth
        textView.blocksTextContainer.containerSize = CGSize(
            width: currentWidth,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.blocksLayoutManager.ensureLayout(for: textView.blocksTextContainer)
        let usedRect = textView.blocksLayoutManager.usedRect(for: textView.blocksTextContainer)
        return ceil(usedRect.height)
    }

    private func reportHeightIfNeeded(_ measuredHeight: CGFloat) {
        guard hasAppliedDocument, measuredHeight > 0, measuredHeight != lastReportedHeight else { return }
        lastReportedHeight = measuredHeight
        onHeightChange?(measuredHeight)
    }

    // MARK: - Code blocks (copy buttons)

    private func syncCodeBlockButtons(with codeBlocks: [MarkdownCodeBlock]) {
        let nextIDs = Set(codeBlocks.map(\.id))
        for id in codeBlockButtons.keys where !nextIDs.contains(id) {
            codeBlockButtons[id]?.removeFromSuperview()
            codeBlockButtons[id] = nil
        }
        for codeBlock in codeBlocks where codeBlockButtons[codeBlock.id] == nil {
            let button = NSButton(
                image: NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Copy code") ?? NSImage(),
                target: self,
                action: #selector(copyCodeBlock(_:))
            )
            button.identifier = NSUserInterfaceItemIdentifier(String(codeBlock.id))
            button.imagePosition = .imageOnly
            button.bezelStyle = .regularSquare
            button.controlSize = .small
            button.translatesAutoresizingMaskIntoConstraints = true
            button.wantsLayer = true
            button.layer?.cornerRadius = 8
            addSubview(button)
            codeBlockButtons[codeBlock.id] = button
        }
    }

    private func layoutCodeBlockButtons() {
        cachedCodeBlockFrames = textView.blocksLayoutManager.codeBlockFrames(in: textView.blocksTextContainer)
        let codeBlockRects = Dictionary(uniqueKeysWithValues: cachedCodeBlockFrames.map { ($0.codeBlock.id, $0.frame) })

        for (id, button) in codeBlockButtons {
            guard let rect = codeBlockRects[id] else {
                button.isHidden = true
                continue
            }
            let convertedRect = textView.convert(rect, to: self)
            button.frame = NSRect(
                x: convertedRect.maxX - Layout.copyButtonSize - Layout.copyButtonInset,
                y: convertedRect.minY + Layout.copyButtonInset,
                width: Layout.copyButtonSize,
                height: Layout.copyButtonSize
            ).integral
        }
        updateCopyButtonVisibility()
    }

    private func updateHoveredCodeBlock(for event: NSEvent) {
        let locationInTextView = textView.convert(event.locationInWindow, from: nil)
        var newHoveredID: Int?
        for (codeBlock, frame) in cachedCodeBlockFrames {
            if frame.contains(locationInTextView) {
                newHoveredID = codeBlock.id
                break
            }
        }
        guard hoveredCodeBlockID != newHoveredID else { return }
        hoveredCodeBlockID = newHoveredID
        updateCopyButtonVisibility()
    }

    private func updateCopyButtonVisibility() {
        for (id, button) in codeBlockButtons {
            button.isHidden = id != hoveredCodeBlockID
        }
    }

    @objc
    private func copyCodeBlock(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue,
              let codeBlockID = Int(identifier),
              let codeBlock = currentDocument?.codeBlocks.first(where: { $0.id == codeBlockID }) else {
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(codeBlock.content, forType: .string)
    }

    // MARK: - Diff overlays

    private func syncDiffOverlays(with specs: [DiffOverlaySpec]) {
        let nextIDs = Set(specs.map(\.id))
        for id in diffOverlayViews.keys where !nextIDs.contains(id) {
            diffOverlayViews[id]?.removeFromSuperview()
            diffOverlayViews[id] = nil
        }
        for spec in specs {
            if let existing = diffOverlayViews[spec.id] {
                existing.configure(spec: spec)
            } else {
                let view = DiffOverlayView()
                view.translatesAutoresizingMaskIntoConstraints = true
                view.configure(spec: spec)
                addSubview(view)
                diffOverlayViews[spec.id] = view
            }
        }
    }

    private func layoutDiffOverlays() {
        guard let document = currentDocument else { return }

        let layoutManager = textView.blocksLayoutManager
        let container = textView.blocksTextContainer

        for spec in document.diffOverlays {
            guard let view = diffOverlayViews[spec.id] else { continue }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: spec.range, actualCharacterRange: nil)
            guard glyphRange.length > 0 else {
                view.isHidden = true
                continue
            }
            let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: container)
            let converted = textView.convert(rect, to: self)
            let width = max(bounds.width, currentWidth)
            view.frame = NSRect(
                x: 0,
                y: converted.minY,
                width: width,
                height: converted.height
            ).integral
            view.isHidden = false
        }
    }

    // MARK: - Tool call popover

    private func showToolCallPopover(groupID: Int, anchorRect: NSRect) {
        guard let document = currentDocument,
              let group = document.toolCallGroups.first(where: { $0.id == groupID }) else { return }

        toolCallPopover?.performClose(nil)

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        let viewController = NSViewController()
        viewController.view = ToolCallGroupPopoverView(items: group.items)
        popover.contentViewController = viewController
        toolCallPopover = popover

        let converted = textView.convert(anchorRect, to: self)
        popover.show(relativeTo: converted, of: self, preferredEdge: .maxY)
    }

    private var colorSchemeThemeName: String {
        switch effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) {
        case .darkAqua: return "atom-one-dark"
        default: return "atom-one-light"
        }
    }
}

// MARK: - Popover content

private final class ToolCallGroupPopoverView: NSView {
    init(items: [ToolCallItem]) {
        super.init(frame: .zero)
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        for item in items {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .firstBaseline
            row.spacing = 6

            let statusImage: NSImage?
            let statusTint: NSColor
            switch item.status {
            case .pending:
                statusImage = NSImage(systemSymbolName: "clock", accessibilityDescription: nil)
                statusTint = .secondaryLabelColor
            case .inProgress:
                statusImage = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: nil)
                statusTint = .secondaryLabelColor
            case .completed:
                statusImage = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
                statusTint = .systemGreen
            case .failed:
                statusImage = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)
                statusTint = .systemRed
            }

            let statusView = NSImageView(image: statusImage ?? NSImage())
            statusView.contentTintColor = statusTint
            statusView.setContentHuggingPriority(.required, for: .horizontal)

            let label = NSTextField(labelWithString: item.title)
            label.font = .systemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
            label.cell?.wraps = false
            label.cell?.isScrollable = true

            row.addArrangedSubview(statusView)
            row.addArrangedSubview(label)
            stack.addArrangedSubview(row)
        }

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            widthAnchor.constraint(lessThanOrEqualToConstant: 320),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Horizontal-only scroll view (forwards vertical scroll to parent)

private final class HorizontalOnlyScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        // Forward vertical scrolls to the parent scroll view (the List)
        if abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) {
            nextResponder?.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }
}

// MARK: - Diff overlay view

final class DiffOverlayView: NSView {
    private let headerContainer = NSView()
    private let pathIcon = NSImageView()
    private let pathLabel = NSTextField(labelWithString: "")
    private let statsLabel = NSTextField(labelWithString: "")
    private let statusIcon = NSImageView()

    private let borderView = NSView()

    private let diffScrollView = HorizontalOnlyScrollView()
    private let diffTextView = SharedDiffTextView()

    private var currentSpec: DiffOverlaySpec?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor(name: nil) { appearance in
            appearance.name == .darkAqua
                ? NSColor.white.withAlphaComponent(0.04)
                : NSColor.black.withAlphaComponent(0.03)
        }.cgColor

        setupHeader()
        setupDiffArea()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func menu(for event: NSEvent) -> NSMenu? {
        markdownAncestorMenu(from: self)
    }

    private func setupHeader() {
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        pathIcon.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        statusIcon.translatesAutoresizingMaskIntoConstraints = false
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

        borderView.wantsLayer = true
        borderView.layer?.backgroundColor = NSColor.separatorColor.cgColor

        headerContainer.addSubview(pathIcon)
        headerContainer.addSubview(pathLabel)
        headerContainer.addSubview(statsLabel)
        headerContainer.addSubview(statusIcon)

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

            statusIcon.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -10),
            statusIcon.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            statusIcon.widthAnchor.constraint(equalToConstant: 14),
            statusIcon.heightAnchor.constraint(equalToConstant: 14),

            borderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            borderView.trailingAnchor.constraint(equalTo: trailingAnchor),
            borderView.topAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            borderView.heightAnchor.constraint(equalToConstant: 0.5),
        ])
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

        let added = spec.newText.isEmpty ? 0 : spec.newText.components(separatedBy: "\n").count
        let removed = (spec.oldText?.isEmpty ?? true) ? 0 : (spec.oldText?.components(separatedBy: "\n").count ?? 0)
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

        switch spec.status {
        case .pending:
            statusIcon.image = NSImage(systemSymbolName: "clock", accessibilityDescription: nil)
            statusIcon.contentTintColor = .secondaryLabelColor
        case .inProgress:
            statusIcon.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: nil)
            statusIcon.contentTintColor = .secondaryLabelColor
        case .completed:
            statusIcon.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
            statusIcon.contentTintColor = .systemGreen
        case .failed:
            statusIcon.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)
            statusIcon.contentTintColor = .systemRed
        }

        // Build diff lines
        var lines: [SharedDiffLine] = []
        if let old = spec.oldText, !old.isEmpty {
            for (i, line) in old.components(separatedBy: "\n").enumerated() {
                lines.append(SharedDiffLine(content: line, kind: .removed, oldLineNumber: i + 1, newLineNumber: nil))
            }
        }
        if !spec.newText.isEmpty {
            for (i, line) in spec.newText.components(separatedBy: "\n").enumerated() {
                lines.append(SharedDiffLine(content: line, kind: .added, oldLineNumber: nil, newLineNumber: i + 1))
            }
        }

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
