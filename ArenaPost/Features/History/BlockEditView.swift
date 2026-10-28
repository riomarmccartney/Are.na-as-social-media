import ArenaKit
import SwiftUI

/// Edits what Are.na lets a block's owner change: the text of a text block,
/// the title and description of any block, and an image's alt text.
struct BlockEditView: View {
    let block: Block
    let onSave: (BlockUpdate) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var title: String
    @State private var description: String
    @State private var altText: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case text, title, description, altText
    }

    init(block: Block, onSave: @escaping (BlockUpdate) async throws -> Void) {
        self.block = block
        self.onSave = onSave
        _text = State(initialValue: block.textMarkdown ?? "")
        _title = State(initialValue: block.title ?? "")
        _description = State(initialValue: block.description?.markdown ?? "")
        _altText = State(initialValue: block.imageAltText ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if block.textMarkdown != nil {
                        ArenaSection("Text") {
                            editor($text, field: .text, minHeight: 200)
                        }
                    }

                    ArenaSection("Title") {
                        TextField("Untitled", text: $title, axis: .vertical)
                            .font(.arenaTitle)
                            .foregroundStyle(.arenaInk)
                            .focused($focusedField, equals: .title)
                    }

                    ArenaSection("Description") {
                        editor($description, field: .description, minHeight: 120)
                    }

                    if block.imageAltText != nil {
                        ArenaSection("Alt text") {
                            TextField("Describe the image for people who can't see it", text: $altText, axis: .vertical)
                                .font(.arenaBody)
                                .foregroundStyle(.arenaBodyInk)
                                .focused($focusedField, equals: .altText)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.arenaSmall)
                            .foregroundStyle(.arenaPrivate)
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(.arenaBackground)
            .navigationTitle("Edit block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .disabled(!canSave)
                    }
                }
            }
            .interactiveDismissDisabled(!changes.isEmpty || isSaving)
            .onAppear {
                focusedField = block.textMarkdown != nil ? .text : .title
            }
        }
    }

    private func editor(_ binding: Binding<String>, field: Field, minHeight: CGFloat) -> some View {
        TextEditor(text: binding)
            .font(.arena(17))
            .foregroundStyle(.arenaBodyInk)
            .scrollContentBackground(.hidden)
            .focused($focusedField, equals: field)
            .frame(minHeight: minHeight)
            .padding(8)
            .arenaFrame()
    }

    /// Only the fields that changed, so the rest are left alone on Are.na.
    private var changes: BlockUpdate {
        var update = BlockUpdate()
        if let original = block.textMarkdown, text != original {
            update.content = text
        }
        if title != (block.title ?? "") {
            update.title = title
        }
        if description != (block.description?.markdown ?? "") {
            update.description = description
        }
        if let original = block.imageAltText, altText != original {
            update.altText = altText
        }
        return update
    }

    private var canSave: Bool {
        // A text block can't be emptied.
        let textIsValid = block.textMarkdown == nil || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return !changes.isEmpty && textIsValid
    }

    private func save() async {
        guard canSave, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await onSave(changes)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension Block {
    /// The markdown of a text block; `nil` for other kinds.
    fileprivate var textMarkdown: String? {
        if case .text(let markdown) = content { return markdown.markdown }
        return nil
    }

    /// An image block's alt text ("" when unset); `nil` for other kinds.
    fileprivate var imageAltText: String? {
        if case .image(let image) = content { return image.altText ?? "" }
        return nil
    }
}
