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
            Image(systemName: toast.kind == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(toast.kind == .success ? Color.green : Color.orange)
            Text(toast.message)
                .font(.subheadline)
                .lineLimit(2)
            if let actionTitle = toast.actionTitle {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
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
