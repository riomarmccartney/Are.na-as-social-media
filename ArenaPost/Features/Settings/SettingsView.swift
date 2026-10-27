import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @AppStorage(PreferenceKey.stripLocation) private var stripLocation = true
    @AppStorage(PreferenceKey.videoQuality) private var videoQuality = VideoQuality.high
    @State private var confirmingSignOut = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    HStack(spacing: 12) {
                        AvatarView(user: app.me, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.me?.name ?? "Signed in")
                                .font(.headline)
                            if let slug = app.me?.slug {
                                Text("@\(slug)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button("Sign out", role: .destructive) {
                        confirmingSignOut = true
                    }
                }

                Section("Channel") {
                    NavigationLink {
                        ChannelPickerView()
                    } label: {
                        LabeledContent("Posting to", value: app.channel?.title ?? "None")
                    }
                }

                Section {
                    Toggle("Remove location from photos and videos", isOn: $stripLocation)
                    Picker("Video quality", selection: $videoQuality) {
                        ForEach(VideoQuality.allCases) { quality in
                            Text(quality.title).tag(quality)
                        }
                    }
                } header: {
                    Text("Posting")
                } footer: {
                    Text("An attached file's name becomes the block title, and your text becomes its description.")
                }

                Section("About") {
                    LabeledContent("Version", value: AppConfig.version)
                    Link("Open Are.na", destination: URL(string: "https://www.are.na")!)
                    Link("Source code", destination: AppConfig.repositoryURL)
                }
            }
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
}
