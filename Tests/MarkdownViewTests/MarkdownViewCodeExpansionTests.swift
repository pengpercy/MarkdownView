//
//  MarkdownViewCodeExpansionTests.swift
//  MarkdownView
//

@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit

    /// A fenced block long enough to be collapsible.
    private func longCodeDocument(lines: Int = 30) -> MarkdownContent {
        let code = (1 ... lines).map { "let line\($0) = \(($0 * 7) % 13)" }.joined(separator: "\n")
        return MarkdownContent(markdown: "Intro.\n\n```swift\n\(code)\n```\n\nOutro.", theme: .default)
    }

    struct MarkdownViewCodeExpansionTests {
        /// The height a view measures must follow `codeBlocksAreExpanded` on
        /// the very first build — hosts measure rows through views that never
        /// ran a layout pass, so the reservation cannot depend on state a
        /// previous layout synced into the code view.
        @MainActor
        @Test("First measurement honours the expansion flag")
        func firstMeasurementHonoursExpansionFlag() {
            let collapsedView = MarkdownTextView()
            collapsedView.codeBlocksAreExpanded = false
            collapsedView.setContentImmediately(longCodeDocument(), theme: .default)
            let collapsedHeight = collapsedView.boundingSize(for: 320).height

            let expandedView = MarkdownTextView()
            expandedView.codeBlocksAreExpanded = true
            expandedView.setContentImmediately(longCodeDocument(), theme: .default)
            let expandedHeight = expandedView.boundingSize(for: 320).height

            #expect(expandedHeight > collapsedHeight + 100)
        }

        /// Flipping the flag must re-measure deterministically in both
        /// directions without a layout pass in between.
        @MainActor
        @Test("Expansion toggles re-measure deterministically")
        func expansionTogglesReMeasureDeterministically() {
            let view = MarkdownTextView()
            view.setContentImmediately(longCodeDocument(), theme: .default)
            view.codeBlocksAreExpanded = false
            let collapsedHeight = view.boundingSize(for: 320).height

            view.codeBlocksAreExpanded = true
            let expandedHeight = view.boundingSize(for: 320).height
            #expect(expandedHeight > collapsedHeight + 100)

            view.codeBlocksAreExpanded = false
            #expect(view.boundingSize(for: 320).height == collapsedHeight)

            view.codeBlocksAreExpanded = true
            #expect(view.boundingSize(for: 320).height == expandedHeight)
        }

        /// A pooled code view keeps the expansion state of its previous
        /// occupant. Installing new content against a collapsed host must not
        /// reserve the stale expanded height for one build.
        @MainActor
        @Test("Stale expanded code view does not flash into a new document")
        func staleExpandedCodeViewDoesNotFlash() {
            let view = MarkdownTextView()
            view.setContentImmediately(longCodeDocument(), theme: .default)
            view.codeBlocksAreExpanded = true
            let expandedHeight = view.boundingSize(for: 320).height
            #expect(expandedHeight > 0)

            // Same view, new document, host back to collapsed — the sizing
            // pool's exact shape when a row is recycled between messages.
            view.codeBlocksAreExpanded = false
            view.setContentImmediately(longCodeDocument(lines: 40), theme: .default)
            let rebuiltHeight = view.boundingSize(for: 320).height

            let reference = MarkdownTextView()
            reference.codeBlocksAreExpanded = false
            reference.setContentImmediately(longCodeDocument(lines: 40), theme: .default)
            let referenceHeight = reference.boundingSize(for: 320).height

            #expect(rebuiltHeight == referenceHeight)
            #expect(rebuiltHeight < expandedHeight)
        }

        /// A rebuild installed while the container has no width must not blank
        /// the code views once the container gets its real size.
        @MainActor
        @Test("Zero-width rebuild keeps code views visible")
        func zeroWidthRebuildKeepsCodeViewsVisible() {
            let view = MarkdownTextView()
            view.frame = .init(x: 0, y: 0, width: 320, height: 800)
            view.setContentImmediately(longCodeDocument(), theme: .default)
            view.layoutIfNeeded()

            // Collapse the container, rebuild, then give it its size back.
            view.frame.size.width = 0
            view.codeBlocksAreExpanded = true
            view.frame.size.width = 320
            view.layoutIfNeeded()

            let codeViews = view.contextViews.compactMap { $0 as? CodeView }
            #expect(!codeViews.isEmpty)
            for codeView in codeViews {
                #expect(!codeView.isHidden)
                #expect(codeView.isExpanded)
            }
        }
    }
#endif
