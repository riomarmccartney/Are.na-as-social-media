import ArenaKit
import SwiftUI

/// Lists the channels you created, and lets you paste a link to one you
/// collaborate on or create a new one.
struct ChannelPickerView: View {
    /// During onboarding there is no way back: a channel must be chosen.
    var isOnboarding = false

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var model = ChannelListModel()
    @State private var filter = ""
    @State private var showingNewChannel = false
    @State private var showingLinkEntry = false
    @State private var linkText = ""
    @State private var validatingID: Int?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Button {
                    showingNewChannel = true
                } label: {
                    Label("New channel…", systemImage: "plus")
                }
                Button {
                    linkText = ""
                    showingLinkEntry = true
                } label: {
                    Label("Paste channel link…", systemImage: "link")
                }
            } footer: {
                if isOnboarding {
                    Text("Everything you post goes to this channel. You can change it later in Settings.")
                }
            }

            Section("Your channels") {
                ForEach(filteredChannels) { channel in
                    Button {
                        Task { await choose(channel) }
                    } label: {
                        ChannelRow(
                            channel: channel,
                            isSelected: app.channel?.id == channel.id,
                            isValidating: validatingID == channel.id
                        )
                    }
                    .tint(.primary)
                    .onAppear {
                        if channel.id == model.channels.last?.id {
                            Task { await loadMore() }
                        }
                    }
                }
                if model.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if model.channels.isEmpty, model.errorMessage == nil {
                    Text("You haven't created any channels yet.")
                        .foregroundStyle(.secondary)
                }
                if let message = model.errorMessage {
                    Text(message)
                        .foregroundStyle(.red)
                }
            }
        }
        .searchable(text: $filter, prompt: "Filter your channels")
        .navigationTitle(isOnboarding ? "Choose a channel" : "Channel")
        .toolbar {
            if isOnboarding {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign out", role: .destructive) { app.signOut() }
                }
            }
        }
        .task { await reload() }
        .refreshable { await reload() }
        .disabled(validatingID != nil)
        .sheet(isPresented: $showingNewChannel) {
            NewChannelSheet { channel in
                showingNewChannel = false
                app.select(channel)
                finish()
            }
        }
        .alert("Paste channel link", isPresented: $showingLinkEntry) {
            TextField("are.na/you/channel-name", text: $linkText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            Button("Use channel") {
                Task { await chooseLink(linkText) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("For channels you collaborate on but didn't create.")
        }
        .alert(
            "Can't use this channel",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var filteredChannels: [Channel] {
        let query = filter.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return model.channels }
        return model.channels.filter { $0.title.localizedStandardContains(query) }
    }

    private func reload() async {
        guard let client = app.client, let me = app.me else { return }
        await model.reload(client: client, userID: me.id)
        if let error = model.lastError { app.handle(error) }
    }

    private func loadMore() async {
        guard let client = app.client, let me = app.me else { return }
        await model.loadMore(client: client, userID: me.id)
    }

    private func choose(_ channel: Channel) async {
        await validateAndSelect(String(channel.id), id: channel.id)
    }

    private func chooseLink(_ text: String) async {
        guard let slug = ChannelLink.slug(from: text) else {
            errorMessage = "That doesn't look like an Are.na channel link."
            return
        }
        await validateAndSelect(slug, id: -1)
    }

    /// Loads the full channel to check that you're allowed to add blocks.
    private func validateAndSelect(_ idOrSlug: String, id: Int) async {
        guard let client = app.client else { return }
        validatingID = id
        defer { validatingID = nil }
        do {
            let channel = try await client.channel(idOrSlug)
            guard channel.can?.addTo == true else {
                errorMessage = "You can't add blocks to “\(channel.title)”."
                return
            }
            app.select(channel)
            finish()
        } catch {
            app.handle(error)
            errorMessage = error.localizedDescription
        }
    }

    private func finish() {
        if !isOnboarding {
            dismiss()
        }
    }
}

private struct ChannelRow: View {
    let channel: Channel
    let isSelected: Bool
    let isValidating: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.title)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let visibility = channel.visibility {
                        Text(visibility.title)
                    }
                    if let blocks = channel.counts?.blocks {
                        Text("· \(blocks) blocks")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if isValidating {
                ProgressView()
            } else if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Selected")
            }
        }
        .contentShape(Rectangle())
    }
}

extension Channel.Visibility {
    var title: String {
        switch self {
        case .public: "Public"
        case .closed: "Closed"
        case .private: "Private"
        }
    }

    var explanation: String {
        switch self {
        case .public: "Anyone can see it and add to it."
        case .closed: "Anyone can see it; only you can add."
        case .private: "Only you can see it."
        }
    }
}
