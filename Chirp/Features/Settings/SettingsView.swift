import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @AppStorage(PreferenceKey.stripLocation) private var stripLocation = true
    @AppStorage(PreferenceKey.videoQuality) private var videoQuality = VideoQuality.high
    @AppStorage(PreferenceKey.commentNotifications) private var commentNotifications = true
    @State private var confirmingSignOut = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    ArenaSection("Account") {
                        HStack(spacing: 12) {
                            AvatarView(user: app.me, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.me?.name ?? "Signed in")
                                    .font(.arenaBodyBold)
                                    .foregroundStyle(.arenaInk)
                                if let slug = app.me?.slug {
                                    Text("@\(slug)")
                                        .font(.arenaSmall)
                                        .foregroundStyle(.arenaSecondary)
                                }
                            }
                            Spacer()
                            Button("Sign out") {
                                confirmingSignOut = true
                            }
                            .buttonStyle(.arena)
                        }
                    }

                    ArenaSection("Posting to") {
                        NavigationLink {
                            ChannelPickerView()
                        } label: {
                            HStack {
                                Text(app.channel?.title ?? "No channel")
                                    .font(.arenaBodyBold)
                                    .foregroundStyle(app.channel?.visibility.color ?? .arenaInk)
                                    .lineLimit(1)
                                Spacer()
                                Text("Change")
                                    .font(.arenaSmallBold)
                                    .foregroundStyle(.arenaSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.arenaTertiary)
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    ArenaSection("Photos and videos") {
                        Toggle(isOn: $stripLocation) {
                            Text("Remove location")
                                .font(.arenaBody)
                                .foregroundStyle(.arenaInk)
                        }
                        Text("An attached file's name becomes the block title, and your text becomes its description.")
                            .font(.arenaSmall)
                            .foregroundStyle(.arenaSecondary)
                    }

                    ArenaSection("Notifications") {
                        Toggle(isOn: $commentNotifications) {
                            Text("New comments on your posts")
                                .font(.arenaBody)
                                .foregroundStyle(.arenaInk)
                        }
                        .onChange(of: commentNotifications) { _, isOn in
                            if isOn {
                                Task { await CommentNotifier.requestAuthorization() }
                            }
                        }
                        Text(
                            "Are.na doesn't send notifications, so the app checks for comments in the background. "
                                + "iOS decides how often, usually within an hour or so."
                        )
                        .font(.arenaSmall)
                        .foregroundStyle(.arenaSecondary)
                    }

                    ArenaOptionList(title: "Video quality", options: VideoQuality.allCases, selection: $videoQuality) { $0.title }

                    ArenaSection("About") {
                        AboutRow(label: "Version") {
                            Text(AppConfig.version)
                                .foregroundStyle(.arenaSecondary)
                        }
                        Link(destination: URL(string: "https://www.are.na")!) {
                            AboutRow(label: "Open Are.na") { linkArrow }
                        }
                        Link(destination: AppConfig.repositoryURL) {
                            AboutRow(label: "Source code") { linkArrow }
                        }
                    }
                }
                .padding(16)
            }
            .background(.arenaBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Sign out of Are.na?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) {
                    dismiss()
                    app.signOut()
                }
            }
        }
    }

    private var linkArrow: some View {
        Image(systemName: "arrow.up.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.arenaTertiary)
    }
}

private struct AboutRow<Trailing: View>: View {
    let label: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.arenaInk)
            Spacer()
            trailing
        }
        .font(.arenaBody)
        .frame(minHeight: 36)
        .contentShape(Rectangle())
    }
}
