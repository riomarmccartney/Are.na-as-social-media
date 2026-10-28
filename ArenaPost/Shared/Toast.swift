import SwiftUI

struct Toast: Identifiable, Equatable {
    enum Kind: Equatable {
        case success
        case failure
    }

    let id = UUID()
    let kind: Kind
    let message: String
    var actionTitle: String?

    static func success(_ message: String, action: String? = nil) -> Toast {
        Toast(kind: .success, message: message, actionTitle: action)
    }

    static func failure(_ message: String, action: String? = nil) -> Toast {
        Toast(kind: .failure, message: message, actionTitle: action)
    }
}

struct ToastView: View {
    let toast: Toast
    var action: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.kind == .success ? "checkmark" : "exclamationmark.triangle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(toast.kind == .success ? Color.arenaOpen : Color.arenaPrivate)
            Text(toast.message)
                .font(.arenaSmallBold)
                .foregroundStyle(.arenaInk)
                .lineLimit(2)
            if let actionTitle = toast.actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.arena)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .background(.arenaBackground, in: RoundedRectangle(cornerRadius: 3))
        .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(.arenaHairline) }
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Shows `toast` at the top and clears it after a few seconds.
    func toast(_ toast: Binding<Toast?>, action: @escaping (Toast) -> Void = { _ in }) -> some View {
        overlay(alignment: .top) {
            if let current = toast.wrappedValue {
                ToastView(toast: current) { action(current) }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: current.id) {
                        try? await Task.sleep(for: .seconds(current.kind == .success ? 3 : 6))
                        if toast.wrappedValue?.id == current.id {
                            toast.wrappedValue = nil
                        }
                    }
            }
        }
        .animation(.snappy, value: toast.wrappedValue)
    }
}
