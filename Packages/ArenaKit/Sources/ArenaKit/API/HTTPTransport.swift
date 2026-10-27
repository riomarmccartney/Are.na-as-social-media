import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The network layer ``ArenaClient`` talks through. Tests swap in a stub.
public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)

    /// Uploads a file as the request body, reporting progress from 0 to 1.
    func upload(
        _ request: URLRequest,
        fromFile fileURL: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> (Data, HTTPURLResponse)
}

/// `URLSession`-backed transport with upload progress.
public final class URLSessionTransport: HTTPTransport {
    private let session: URLSession
    private let delegate: ProgressDelegate

    public init(configuration: URLSessionConfiguration = .default) {
        let delegate = ProgressDelegate()
        self.delegate = delegate
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    deinit {
        session.finishTasksAndInvalidate()
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await run { completion in
            session.dataTask(with: request, completionHandler: completion)
        }
    }

    public func upload(
        _ request: URLRequest,
        fromFile fileURL: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> (Data, HTTPURLResponse) {
        try await run(progress: progress) { completion in
            session.uploadTask(with: request, fromFile: fileURL, completionHandler: completion)
        }
    }

    private func run(
        progress: (@Sendable (Double) -> Void)? = nil,
        makeTask: (@escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionTask
    ) async throws -> (Data, HTTPURLResponse) {
        let box = TaskBox()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let delegate = delegate
                let task = makeTask { data, response, error in
                    if let id = box.task?.taskIdentifier {
                        delegate.removeHandler(for: id)
                    }
                    if let error = error as? URLError, error.code == .cancelled {
                        continuation.resume(throwing: CancellationError())
                    } else if let error {
                        continuation.resume(throwing: ArenaError.transport(error.localizedDescription))
                    } else if let response = response as? HTTPURLResponse {
                        continuation.resume(returning: (data ?? Data(), response))
                    } else {
                        continuation.resume(throwing: ArenaError.invalidResponse)
                    }
                }
                if let progress {
                    delegate.setHandler(progress, for: task.taskIdentifier)
                }
                box.task = task
                task.resume()
            }
        } onCancel: {
            box.task?.cancel()
        }
    }
}

/// Holds the running task so cancellation can reach it.
private final class TaskBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _task: URLSessionTask?

    var task: URLSessionTask? {
        get { lock.withLock { _task } }
        set { lock.withLock { _task = newValue } }
    }
}

private final class ProgressDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var handlers: [Int: @Sendable (Double) -> Void] = [:]

    func setHandler(_ handler: @escaping @Sendable (Double) -> Void, for taskID: Int) {
        lock.withLock { handlers[taskID] = handler }
    }

    func removeHandler(for taskID: Int) {
        _ = lock.withLock { handlers.removeValue(forKey: taskID) }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0,
              let handler = lock.withLock({ handlers[task.taskIdentifier] })
        else { return }
        handler(Double(totalBytesSent) / Double(totalBytesExpectedToSend))
    }
}
