import SwiftUI
import WidgetKit

@main
struct ArenaPostWidgets: WidgetBundle {
    var body: some Widget {
        NewPostWidget()
    }
}

/// Opens the composer from the Home Screen or Lock Screen. Widgets can't take
/// typing, so they're shortcuts into the app.
struct NewPostWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NewPost", provider: Provider()) { _ in
            NewPostView()
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName("New post")
        .description("Start a post to your Are.na channel.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryInline])
    }
}

/// The widget never changes, so it has a single entry.
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry { SimpleEntry() }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        completion(Timeline(entries: [SimpleEntry()], policy: .never))
    }
}

struct SimpleEntry: TimelineEntry {
    let date = Date.now
}

struct NewPostView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                ArenaStar()
                    .fill(.primary)
                    .padding(12)
            }
            .widgetURL(ComposeLink.write.url)
            .accessibilityLabel("New post")

        case .accessoryInline:
            Label("New post", systemImage: "square.and.pencil")
                .widgetURL(ComposeLink.write.url)

        case .systemMedium:
            HStack(alignment: .top, spacing: 16) {
                header
                Spacer(minLength: 0)
                VStack(spacing: 8) {
                    ShortcutButton(link: .write, title: "Write", systemImage: "text.alignleft")
                    ShortcutButton(link: .photo, title: "Photo", systemImage: "photo")
                    ShortcutButton(link: .camera, title: "Camera", systemImage: "camera")
                }
                .frame(width: 128)
            }

        default:
            header
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .widgetURL(ComposeLink.write.url)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            ArenaStar()
                .fill(.primary)
                .frame(width: 22, height: 26)
            Spacer(minLength: 12)
            Text("New post")
                .font(.custom("Arial-BoldMT", size: 17, relativeTo: .headline))
            Text("to Are.na")
                .font(.custom("ArialMT", size: 13, relativeTo: .footnote))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A row in the medium widget, styled like Are.na's small grey buttons.
private struct ShortcutButton: View {
    let link: ComposeLink
    let title: String
    let systemImage: String

    var body: some View {
        Link(destination: link.url) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .frame(width: 18)
                Text(title)
                Spacer(minLength: 0)
            }
            .font(.custom("Arial-BoldMT", size: 13, relativeTo: .footnote))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 32)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 3))
        }
    }
}

#Preview(as: .systemMedium) {
    NewPostWidget()
} timeline: {
    SimpleEntry()
}
