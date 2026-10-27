import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import ArenaKit

/// Records requests and answers them from a handler.
final class StubTransport: HTTPTransport, @unchecked Sendable {
    struct Recorded {
        let request: URLRequest
        let uploadedFile: URL?
    }

    typealias Handler = @Sendable (URLRequest) -> (status: Int, body: String)

    private let lock = NSLock()
    private var recorded: [Recorded] = []
    private let handler: Handler

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    convenience init(status: Int = 200, body: String) {
        self.init { _ in (status, body) }
    }

    var requests: [Recorded] { lock.withLock { recorded } }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.withLock { recorded.append(Recorded(request: request, uploadedFile: nil)) }
        return respond(to: request)
    }

    func upload(
        _ request: URLRequest,
        fromFile fileURL: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> (Data, HTTPURLResponse) {
        lock.withLock { recorded.append(Recorded(request: request, uploadedFile: fileURL)) }
        progress(0.5)
        progress(1)
        return respond(to: request)
    }

    private func respond(to request: URLRequest) -> (Data, HTTPURLResponse) {
        let (status, body) = handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        return (Data(body.utf8), response)
    }
}

extension URLRequest {
    var jsonBody: [String: Any]? {
        httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }

    var queryItems: [String: String] {
        let items = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }
}
