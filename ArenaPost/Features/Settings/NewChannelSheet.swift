import ArenaKit
import SwiftUI

struct NewChannelSheet: View {
    let onCreate: (Channel) -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var visibility: Channel.Visibility = .closed
    @State private var isCreating = false
    @State private var errorMessage: String?
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Channel name", text: $title)
                        .focused($isTitleFocused)
                        .submitLabel(.done)
                        .onSubmit { Task { await create() } }
                }
                Section {
                    Picker("Visibility", selection: $visibility) {
                        ForEach(Channel.Visibility.allCases, id: \.self) { visibility in
                            Text(visibility.title).tag(visibility)
                        }
                    }
                } footer: {
                    Text(visibility.explanation)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New channel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isCreating {
                        ProgressView()
                    } else {
                        Button("Create") { Task { await create() } }
                            .disabled(trimmedTitle.isEmpty)
                    }
                }
            }
            .onAppear { isTitleFocused = true }
        }
        .presentationDetents([.medium])
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func create() async {
        guard let client = app.client, !trimmedTitle.isEmpty, !isCreating else { return }
        isCreating = true
        defer { isCreating = false }
        do {
            // The presenter dismisses this sheet once it has used the channel.
            onCreate(try await client.createChannel(title: trimmedTitle, visibility: visibility))
        } catch {
            app.handle(error)
            errorMessage = error.localizedDescription
        }
    }
}
