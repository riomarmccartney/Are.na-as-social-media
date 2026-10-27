import ArenaKit
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The home screen: a Threads-style composer that posts one block per post.
struct ComposerView: View {
    @Environment(AppModel.self) private var app

    @State private var model = ComposerModel(draft: UserDefaults.standard.string(forKey: PreferenceKey.draft) ?? "")
    @FocusState private var isEditorFocused: Bool

    @State private var showingHistory = false
    @State private var showingSettings = false
    @State private var showingChannelPicker = false
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var showingFileImporter = false
    @State private var photoItem: PhotosPickerItem?

    @AppStorage(PreferenceKey.stripLocation) private var stripLocation = true
    @AppStorage(PreferenceKey.videoQuality) private var videoQuality = VideoQuality.high

    var body: some View {
        NavigationStack {
            ScrollView {
                editor
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { composerBar }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .navigationDestination(isPresented: $showingHistory) { HistoryView() }
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: $showingChannelPicker) {
            NavigationStack { ChannelPickerView() }
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $photoItem,
            matching: .any(of: [.images, .videos]),
            preferredItemEncoding: .current,
            photoLibrary: .shared()
        )
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            Task { await model.attach(item, stripLocation: stripLocation, videoQuality: videoQuality) }
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.item]) { result in
            if case .success(let url) = result {
                Task { await model.attachFile(at: url) }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { capture in
                showingCamera = false
                if let capture {
                    Task { await model.attach(capture, stripLocation: stripLocation, videoQuality: videoQuality) }
                }
            }
            .ignoresSafeArea()
        }
        .toast($model.toast) { toast in
            if toast.kind == .success {
                showingHistory = true
            } else {
                post()
            }
            model.toast = nil
        }
        .sensoryFeedback(.success, trigger: model.postCount)
        .onChange(of: model.text) { _, text in
            UserDefaults.standard.set(text, forKey: PreferenceKey.draft)
        }
        .onChange(of: showingHistory) { _, isShowing in
            if !isShowing { isEditorFocused = true }
        }
        .onAppear { isEditorFocused = true }
    }

    // MARK: Editor

    private var editor: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(user: app.me, size: 36)

            VStack(alignment: .leading, spacing: 10) {
                Text(app.me?.name ?? "You")
                    .font(.subheadline.weight(.semibold))

                TextField(placeholder, text: $model.text, axis: .vertical)
                    .focused($isEditorFocused)
                    .font(.body)
                    .disabled(model.phase != .idle)

                if model.isPreparingAttachment {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Preparing…")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                } else if let attachment = model.attachment {
                    AttachmentPreview(attachment: attachment) {
                        model.removeAttachment()
                    }
                    .disabled(model.phase != .idle)
                } else if let url = model.linkURL {
                    LinkPreview(url: url)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isEditorFocused = true }
    }

    private var placeholder: String {
        if model.attachment != nil { return "Add a description…" }
        return "Post to \(app.channel?.title ?? "Are.na")…"
    }

    // MARK: Bottom bar

    private var composerBar: some View {
        HStack(spacing: 22) {
            Group {
                Button {
                    showingPhotoPicker = true
                } label: {
                    Image(systemName: "photo.on.rectangle")
                }
                .accessibilityLabel("Add photo or video")

                Button {
                    showingCamera = true
                } label: {
                    Image(systemName: "camera")
                }
                .accessibilityLabel("Take photo or video")
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

                Button {
                    showingFileImporter = true
                } label: {
                    Image(systemName: "paperclip")
                }
                .accessibilityLabel("Attach file")

                PasteButton(payloadType: String.self) { strings in
                    guard let string = strings.first else { return }
                    Task { @MainActor in model.insertLink(string) }
                }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.circle)
                .controlSize(.small)
            }
            .disabled(!model.canAttach)
            .font(.title3)

            Spacer()

            postButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var postButton: some View {
        Button {
            post()
        } label: {
            Group {
                if case .posting(let progress) = model.phase {
                    ProgressRing(progress: progress)
                        .frame(width: 18, height: 18)
                        .accessibilityLabel("Posting")
                } else {
                    Text("Post")
                        .fontWeight(.semibold)
                }
            }
            .frame(minWidth: 52)
        }
        .buttonStyle(.glassProminent)
        .disabled(!model.canPost)
    }

    private func post() {
        guard let client = app.client, let channel = app.channel else { return }
        model.post(client: client, channel: channel) {
            app.signOut()
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showingHistory = true
            } label: {
                Label("Past posts", systemImage: "clock.arrow.circlepath")
            }
        }
        ToolbarItem(placement: .principal) {
            Button {
                showingChannelPicker = true
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.tint)
                        .frame(width: 6, height: 6)
                    Text(app.channel?.title ?? "Choose channel")
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .tint(.primary)
            .accessibilityLabel("Channel: \(app.channel?.title ?? "none"). Change channel")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

/// Determinate ring, or a spinner when progress is unknown.
private struct ProgressRing: View {
    let progress: Double?

    var body: some View {
        if let progress {
            ZStack {
                Circle().stroke(.white.opacity(0.35), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: max(0.02, progress))
                    .stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: progress)
            }
        } else {
            ProgressView()
                .tint(.white)
                .controlSize(.small)
        }
    }
}
