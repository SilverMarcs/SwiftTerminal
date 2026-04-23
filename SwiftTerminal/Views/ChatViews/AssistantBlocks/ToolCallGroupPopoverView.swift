import AppKit

final class ToolCallGroupPopoverView: NSView {
    private static let maxHeight: CGFloat = 300
    private static let popoverWidth: CGFloat = 480
    private static let padding: CGFloat = 10
    private static let rowHeight: CGFloat = 20
    private static let rowSpacing: CGFloat = 2

    init(items: [ToolCallItem]) {
        super.init(frame: .zero)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.rowSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false

        for item in items {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
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
            statusView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            statusView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                statusView.widthAnchor.constraint(equalToConstant: 14),
                statusView.heightAnchor.constraint(equalToConstant: 14),
            ])

            let label = NSTextField(labelWithString: item.title)
            label.font = .monospacedSystemFont(ofSize: 11.5, weight: .regular)
            label.textColor = .labelColor
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
            label.cell?.wraps = false

            row.addArrangedSubview(statusView)
            row.addArrangedSubview(label)
            stack.addArrangedSubview(row)
        }

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: Self.padding),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: Self.padding),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -Self.padding),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -Self.padding),
        ])

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.documentView = documentView

        NSLayoutConstraint.activate([
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])

        addSubview(scrollView)

        let contentHeight = Self.padding * 2
            + CGFloat(items.count) * Self.rowHeight
            + CGFloat(max(0, items.count - 1)) * Self.rowSpacing
        let resolvedHeight = min(contentHeight, Self.maxHeight)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthAnchor.constraint(equalToConstant: Self.popoverWidth),
            heightAnchor.constraint(equalToConstant: resolvedHeight),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
