import SwiftUI

struct DiffPanel: View {
    let reference: GitDiffReference
    @Environment(EditorPanel.self) private var panel
    @State private var presentation: GitDiffPresentation?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let presentation {
                DiffTextView(
                    presentation: presentation,
                    fileExtension: reference.fileURL.pathExtension.lowercased()
                )
            }
        }
        .task(id: reference) { await loadDiff() }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(nsImage: reference.fileURL.fileIcon)
                .resizable()
                .frame(width: 16, height: 16)
            Text(reference.fileURL.lastPathComponent)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            GitStatusBadge(kind: reference.kind, staged: reference.stage == .staged)

            Spacer()

            Button { panel.close() } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Close")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func loadDiff() async {
        isLoading = true
        do {
            presentation = try await GitRepository.shared.diffPresentation(for: reference)
        } catch {
            presentation = GitDiffPresentation(message: "Failed to load diff: \(error.localizedDescription)")
        }
        isLoading = false
    }
}

// MARK: - Diff NSTextView with line backgrounds

struct DiffTextView: NSViewRepresentable {
    let presentation: GitDiffPresentation
    var fileExtension: String = ""

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = DiffScrollableTextView.create(presentation: presentation, fileExtension: fileExtension)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {}
}

/// Custom NSTextView that draws full-width colored backgrounds behind diff lines.
final class DiffLineBackgroundTextView: NSTextView {
    var lineKinds: [Int: GitDiffLineKind] = [:]
    var hunkSeparatorLines: Set<Int> = []

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)

        guard let layoutManager = self.layoutManager,
              let textContainer = self.textContainer
        else { return }

        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: rect, in: textContainer)
        let visibleCharRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)

        let text = (self.string as NSString)
        let containerOrigin = self.textContainerOrigin

        // Walk through each visible line
        text.enumerateSubstrings(
            in: visibleCharRange,
            options: [.byLines, .substringNotRequired]
        ) { _, substringRange, enclosingRange, _ in
            let lineNumber = self.lineNumber(forCharacterIndex: substringRange.location)

            // Determine the background color
            let bgColor: NSColor?
            if self.hunkSeparatorLines.contains(lineNumber) {
                bgColor = NSColor.separatorColor.withAlphaComponent(0.15)
            } else if let kind = self.lineKinds[lineNumber] {
                switch kind {
                case .added:
                    bgColor = NSColor.systemGreen.withAlphaComponent(0.15)
                case .removed:
                    bgColor = NSColor.systemRed.withAlphaComponent(0.15)
                }
            } else {
                bgColor = nil
            }

            guard let color = bgColor else { return }

            let glyphRange = layoutManager.glyphRange(forCharacterRange: enclosingRange, actualCharacterRange: nil)
            var lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            lineRect.origin.x = 0
            lineRect.origin.y += containerOrigin.y
            lineRect.size.width = self.bounds.width

            color.setFill()
            lineRect.fill()
        }
    }

    private func lineNumber(forCharacterIndex index: Int) -> Int {
        let text = self.string as NSString
        var lineNum = 1
        var i = 0
        while i < index && i < text.length {
            if text.character(at: i) == 0x0A { // \n
                lineNum += 1
            }
            i += 1
        }
        return lineNum
    }
}

enum DiffScrollableTextView {
    static func create(presentation: GitDiffPresentation, fileExtension: String = "") -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true

        let textView = DiffLineBackgroundTextView()
        textView.lineKinds = presentation.lineKinds
        textView.hunkSeparatorLines = presentation.hunkSeparatorLines
        textView.isEditable = false
        textView.isSelectable = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = .textBackgroundColor
        textView.drawsBackground = true
        textView.textColor = .textColor
        textView.textContainerInset = NSSize(width: 2, height: 2)
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        // Start with syntax highlighting, then overlay diff colors
        let attributed: NSMutableAttributedString
        if !fileExtension.isEmpty {
            attributed = NSMutableAttributedString(
                attributedString: SyntaxHighlighter.highlight(presentation.string, fileExtension: fileExtension)
            )
        } else {
            attributed = NSMutableAttributedString(
                string: presentation.string,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: NSColor.labelColor,
                ]
            )
        }

        // Overlay diff foreground tint on added/removed lines
        let text = presentation.string as NSString
        var lineStart = 0
        var lineNum = 1
        while lineStart < text.length {
            var lineEnd = 0
            var contentsEnd = 0
            text.getLineStart(nil, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: lineStart, length: 0))

            if let kind = presentation.lineKinds[lineNum] {
                let range = NSRange(location: lineStart, length: contentsEnd - lineStart)
                let color: NSColor = kind == .added ? .systemGreen : .systemRed
                attributed.addAttribute(.foregroundColor, value: color, range: range)
            }

            lineStart = lineEnd
            lineNum += 1

            if lineEnd == lineStart && lineStart < text.length {
                break
            }
        }

        textView.textStorage?.setAttributedString(attributed)

        scrollView.documentView = textView
        return scrollView
    }
}
