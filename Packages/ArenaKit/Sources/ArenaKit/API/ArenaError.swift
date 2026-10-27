import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum ArenaError: Error, Sendable, Equatable {
    /// 401 — the token is missing, invalid or was revoked.
    case unauthorized
    /// 403 — e.g. a `read`-scoped token tried to write, or no access to the channel.
    case forbidden(message: String?)
    case notFound
    /// 429 — wait `retryAfter` seconds before trying again.
    case rateLimited(retryAfter: TimeInterval?)
    case server(status: Int, message: String?)
    case invalidResponse
    case decoding(String)
    case transport(String)
}

extension ArenaError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            "Your Are.na session has expired. Sign in again."
        case .forbidden(let message):
            message ?? "You don't have permission to do that on Are.na."
        case .notFound:
            "That doesn't exist on Are.na anymore."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                "Are.na is rate limiting requests. Try again in \(Int(retryAfter.rounded(.up))) s."
            } else {
                "Are.na is rate limiting requests. Try again in a moment."
            }
        case .server(let status, let message):
            message ?? "Are.na returned an error (\(status))."
        case .invalidResponse:
            "Are.na sent an unexpected response."
        case .decoding:
            "Couldn't read Are.na's response."
        case .transport(let message):
            message
        }
    }
}

extension ArenaError {
    /// Maps a non-2xx response to an error, reading Are.na's error bodies:
    /// `{ error, code, details: { message } }` and, for 429,
    /// `{ error: { message, retry_after } }`.
    static func from(status: Int, body: Data, headers: HTTPURLResponse?) -> ArenaError {
        let parsed = try? JSONDecoder().decode(ErrorBody.self, from: body)
        let message = parsed?.message
        switch status {
        case 401:
            return .unauthorized
        case 403:
            return .forbidden(message: message)
        case 404:
            return .notFound
        case 429:
            let header = headers?.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            return .rateLimited(retryAfter: parsed?.retryAfter ?? header)
        default:
            return .server(status: status, message: message)
        }
    }
}

private struct ErrorBody: Decodable {
    let message: String?
    let retryAfter: TimeInterval?

    private struct Details: Decodable {
        let message: String?
    }

    private struct RateLimit: Decodable {
        let message: String?
        let retryAfter: TimeInterval?

        enum CodingKeys: String, CodingKey {
            case message
            case retryAfter = "retry_after"
        }
    }

    enum CodingKeys: String, CodingKey {
        case error, details
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let rateLimit = try? container.decode(RateLimit.self, forKey: .error) {
            message = rateLimit.message
            retryAfter = rateLimit.retryAfter
        } else {
            let details = try? container.decodeIfPresent(Details.self, forKey: .details)
            message = details?.message ?? (try? container.decodeIfPresent(String.self, forKey: .error))
            retryAfter = nil
        }
    }
}
