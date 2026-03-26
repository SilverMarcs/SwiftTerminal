import AppKit
import SwiftUI

struct FileEditorPanel: View {
    let fileURL: URL
    let directoryURL: URL
    @Environment(EditorPanel.self) private var panel
    @State private var content: String = ""
    @State private var savedContent: String = ""
    @State private var isLoaded = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var gutterDiff: GutterDiffResult = .empty

    private var hasUnsavedChanges: Bool {
        isLoaded && content != savedContent
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if isLoaded {
                HighlightedTextEditor(
                    text: $content,
                    fileExtension: fileURL.pathExtension.lowercased(),
                    gutterDiff: gutterDiff
                )
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Cannot Open File", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: fileURL) { loadFile() }
        .onChange(of: hasUnsavedChanges) { _, dirty in
            panel.isDirty = dirty
        }
        .alert("Unsaved Changes", isPresented: Binding(
            get: { panel.showUnsavedAlert },
            set: { if !$0 { panel.cancelDiscard() } }
        )) {
            Button("Save") {
                saveFile()
                panel.confirmDiscard()
            }
            Button("Discard", role: .destructive) {
                panel.confirmDiscard()
            }
            Button("Cancel", role: .cancel) {
                panel.cancelDiscard()
            }
        } message: {
            Text("Do you want to save changes to \"\(fileURL.lastPathComponent)\"?")
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(nsImage: fileURL.fileIcon)
                .resizable()
                .frame(width: 16, height: 16)
            Text(fileURL.lastPathComponent)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)

            if hasUnsavedChanges {
                Circle()
                    .fill(.secondary)
                    .frame(width: 6, height: 6)
                    .help("Unsaved changes")
            }

            Spacer()

            if isSaving {
                ProgressView()
                    .controlSize(.small)
            }

            Button { saveFile() } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!hasUnsavedChanges || isSaving)
            .help("Save")

            Button { panel.close() } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Close")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func loadFile() {
        content = ""
        savedContent = ""
        isLoaded = false
        errorMessage = nil
        gutterDiff = .empty
        panel.isDirty = false
        do {
            let data = try Data(contentsOf: fileURL)
            guard let string = String(data: data, encoding: .utf8) else {
                errorMessage = "Binary file — cannot display."
                return
            }
            content = string
            savedContent = string
            isLoaded = true
            loadGutterDiff()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveFile() {
        isSaving = true
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            savedContent = content
            loadGutterDiff()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private func loadGutterDiff() {
        Task {
            do {
                gutterDiff = try await GitRepository.shared.gutterDiff(for: fileURL, in: directoryURL)
            } catch {
                gutterDiff = .empty
            }
        }
    }
}

// MARK: - NSTextView wrapper with syntax highlighting

private let gutterWidth: CGFloat = 44
private let markerBarWidth: CGFloat = 3

struct HighlightedTextEditor: NSViewRepresentable {
    @Binding var text: String
    let fileExtension: String
    var gutterDiff: GutterDiffResult

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let contentSize = scrollView.contentSize
        let textContainer = NSTextContainer(containerSize: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = false

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)

        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        let textView = EditorTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: gutterWidth, height: 4)
        textView.delegate = context.coordinator

        // Horizontal scrolling (no line wrapping)
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: contentSize.width, height: 0)
        textView.autoresizingMask = [.width]

        // To enable line wrapping instead, uncomment the following and comment out the horizontal scrolling block above:
        // textView.isHorizontallyResizable = false
        // textView.isVerticallyResizable = true
        // textView.textContainer?.widthTracksTextView = true
        // textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        // textView.autoresizingMask = [.width]

        scrollView.documentView = textView

        textView.gutterDiff = gutterDiff
        context.coordinator.textView = textView

        // Initial content
        let highlighted = SyntaxHighlighter.highlight(text, fileExtension: fileExtension)
        textView.textStorage?.setAttributedString(highlighted)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? EditorTextView else { return }

        textView.gutterDiff = gutterDiff
        textView.needsDisplay = true

        // Only update if the binding changed externally (not from editing)
        if !context.coordinator.isEditing, textView.string != text {
            let highlighted = SyntaxHighlighter.highlight(text, fileExtension: fileExtension)
            textView.textStorage?.setAttributedString(highlighted)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: HighlightedTextEditor
        weak var textView: EditorTextView?
        var isEditing = false
        private var rehighlightTask: DispatchWorkItem?

        init(_ parent: HighlightedTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isEditing = true
            parent.text = textView.string
            isEditing = false

            // Debounced re-highlight
            rehighlightTask?.cancel()
            let task = DispatchWorkItem { [weak self] in
                guard let self, let tv = self.textView else { return }
                let source = tv.string
                let ext = self.parent.fileExtension
                let selectedRanges = tv.selectedRanges
                let highlighted = SyntaxHighlighter.highlight(source, fileExtension: ext)
                tv.textStorage?.setAttributedString(highlighted)
                tv.setSelectedRanges(selectedRanges, affinity: .downstream, stillSelecting: false)
            }
            rehighlightTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
        }
    }
}

// MARK: - Editor Text View with Gutter

final class EditorTextView: NSTextView {
    var gutterDiff: GutterDiffResult = .empty

    private let lineNumberFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)

        guard let layoutManager, let textContainer else { return }

        let containerOrigin = textContainerOrigin
        let text = string as NSString

        // Draw gutter background
        let gutterRect = NSRect(x: 0, y: rect.minY, width: gutterWidth, height: rect.height)
        NSColor.controlBackgroundColor.withAlphaComponent(0.3).setFill()
        gutterRect.fill()

        // Draw gutter separator
        NSColor.separatorColor.withAlphaComponent(0.3).setStroke()
        NSBezierPath.strokeLine(
            from: NSPoint(x: gutterWidth - 0.5, y: rect.minY),
            to: NSPoint(x: gutterWidth - 0.5, y: rect.maxY)
        )

        guard text.length > 0 else { return }

        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: rect, in: textContainer)
        let visibleCharRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)

        let lineNumAttrs: [NSAttributedString.Key: Any] = [
            .font: lineNumberFont,
            .foregroundColor: NSColor.secondaryLabelColor,
        ]

        // Count lines before visible range
        var startLineNumber = 1
        if visibleCharRange.location > 0 {
            let preText = text.substring(to: visibleCharRange.location)
            startLineNumber = preText.components(separatedBy: "\n").count
        }

        var lineNumber = startLineNumber
        var charIndex = visibleCharRange.location
        let endChar = NSMaxRange(visibleCharRange)

        while charIndex <= endChar && charIndex < text.length {
            let lineRange = text.lineRange(for: NSRange(location: charIndex, length: 0))
            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)

            if glyphRange.location != NSNotFound {
                var lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                lineRect.origin.x += containerOrigin.x
                lineRect.origin.y += containerOrigin.y

                if lineRect.minY + lineRect.height >= rect.minY && lineRect.minY <= rect.maxY {
                    // Draw line number right-aligned
                    let numStr = "\(lineNumber)" as NSString
                    let size = numStr.size(withAttributes: lineNumAttrs)
                    let x = gutterWidth - markerBarWidth - size.width - 6
                    let y = lineRect.minY + (lineRect.height - size.height) / 2
                    numStr.draw(at: NSPoint(x: x, y: y), withAttributes: lineNumAttrs)

                    // Draw git change marker bar
                    if let kind = gutterDiff.markers[lineNumber] {
                        kind.color.setFill()
                        if kind == .deleted {
                            NSRect(
                                x: gutterWidth - markerBarWidth - 1,
                                y: lineRect.minY - 1,
                                width: markerBarWidth + 1,
                                height: 3
                            ).fill()
                        } else {
                            NSRect(
                                x: gutterWidth - markerBarWidth - 1,
                                y: lineRect.minY,
                                width: markerBarWidth,
                                height: lineRect.height
                            ).fill()
                        }
                    }
                }
            }

            lineNumber += 1
            let nextIndex = NSMaxRange(lineRange)
            if nextIndex <= charIndex { break }
            charIndex = nextIndex
        }
    }

    // MARK: - Click handling for gutter diff popover

    override func mouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)

        // Only intercept clicks in the gutter area
        guard localPoint.x < gutterWidth else {
            super.mouseDown(with: event)
            return
        }

        guard let layoutManager, let textContainer else { return }

        let text = string as NSString
        guard text.length > 0 else { return }

        let containerOrigin = textContainerOrigin
        let textPoint = NSPoint(x: containerOrigin.x, y: localPoint.y - containerOrigin.y)

        let charIndex = layoutManager.characterIndex(
            for: textPoint, in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        let preText = text.substring(to: min(charIndex, text.length))
        let clickedLine = preText.components(separatedBy: "\n").count

        guard gutterDiff.markers[clickedLine] != nil else { return }

        guard let hunk = gutterDiff.hunks.first(where: { hunk in
            if hunk.kind == .deleted {
                return clickedLine == max(hunk.newStart, 1)
            } else {
                return clickedLine >= hunk.newStart && clickedLine < hunk.newStart + hunk.newCount
            }
        }) else { return }

        showDiffPopover(for: hunk, at: localPoint)
    }

    private func showDiffPopover(for hunk: GutterDiffHunk, at point: NSPoint) {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        let viewController = NSViewController()
        let container = NSView()

        // Title
        let titleLabel = NSTextField(labelWithString: hunkTitle(for: hunk))
        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Diff content
        let diffScrollView = NSTextView.scrollableTextView()
        let diffTextView = diffScrollView.documentView as! NSTextView
        diffTextView.isEditable = false
        diffTextView.isSelectable = true
        diffTextView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        diffTextView.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.5)
        diffTextView.textContainerInset = NSSize(width: 6, height: 4)
        diffScrollView.translatesAutoresizingMaskIntoConstraints = false
        diffScrollView.hasVerticalScroller = true
        diffScrollView.borderType = .noBorder

        diffTextView.textStorage?.setAttributedString(buildDiffAttributedString(for: hunk))

        container.addSubview(titleLabel)
        container.addSubview(diffScrollView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            diffScrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            diffScrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            diffScrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            diffScrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        viewController.view = container
        let oldLineCount = hunk.oldContent.isEmpty ? 0 : hunk.oldContent.components(separatedBy: "\n").count
        let totalLines = max(oldLineCount + hunk.newCount, 1)
        let height = min(CGFloat(totalLines) * 16 + 44, 300)
        viewController.preferredContentSize = NSSize(width: 400, height: height)

        popover.contentViewController = viewController

        let anchorRect = NSRect(x: gutterWidth - 2, y: point.y - 4, width: 4, height: 8)
        popover.show(relativeTo: anchorRect, of: self, preferredEdge: .maxX)
    }

    private func hunkTitle(for hunk: GutterDiffHunk) -> String {
        switch hunk.kind {
        case .added:
            "Added \(hunk.newCount) line\(hunk.newCount == 1 ? "" : "s")"
        case .modified:
            "Modified \(hunk.newCount) line\(hunk.newCount == 1 ? "" : "s")"
        case .deleted:
            "Deleted \(hunk.oldCount) line\(hunk.oldCount == 1 ? "" : "s")"
        }
    }

    private func buildDiffAttributedString(for hunk: GutterDiffHunk) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let baseFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let removedBg = NSColor.systemRed.withAlphaComponent(0.15)
        let addedBg = NSColor.systemGreen.withAlphaComponent(0.15)

        if !hunk.oldContent.isEmpty {
            for line in hunk.oldContent.components(separatedBy: "\n") {
                result.append(NSAttributedString(
                    string: "- " + line + "\n",
                    attributes: [.font: baseFont, .foregroundColor: NSColor.systemRed, .backgroundColor: removedBg]
                ))
            }
        }

        if hunk.kind == .added || hunk.kind == .modified, hunk.newCount > 0 {
            let currentLines = string.components(separatedBy: "\n")
            let start = max(hunk.newStart - 1, 0)
            let end = min(start + hunk.newCount, currentLines.count)
            for i in start..<end {
                result.append(NSAttributedString(
                    string: "+ " + currentLines[i] + "\n",
                    attributes: [.font: baseFont, .foregroundColor: NSColor.systemGreen, .backgroundColor: addedBg]
                ))
            }
        }

        return result
    }
}
