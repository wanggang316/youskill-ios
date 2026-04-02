import Foundation

enum TranslationValidationErrorFormatter {
    static func message(for error: Error) -> String {
        if let error = error as? TranslationRepositoryError {
            return error.localizedDescription
        }

        if let error = error as? HTTPClientError {
            switch error {
            case let .badStatusCode(code, message):
                switch code {
                case 400:
                    return message.isEmpty ? L10n.string("validation.bad_request") : message
                case 401, 403:
                    return message.isEmpty ? L10n.string("validation.invalid_key") : message
                case 404:
                    return message.isEmpty ? L10n.string("validation.endpoint_not_found") : message
                case 429:
                    return message.isEmpty ? L10n.string("validation.rate_limited") : message
                default:
                    return message.isEmpty ? L10n.format("validation.server_error", code) : message
                }
            case .invalidResponse:
                return L10n.string("validation.invalid_response")
            case .emptyResponse:
                return L10n.string("validation.empty_response")
            }
        }

        if let error = error as? URLError {
            switch error.code {
            case .timedOut:
                return L10n.string("validation.timeout")
            case .notConnectedToInternet:
                return L10n.string("validation.offline")
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return L10n.string("validation.cannot_connect")
            case .networkConnectionLost:
                return L10n.string("validation.network_lost")
            case .secureConnectionFailed,
                 .serverCertificateHasBadDate,
                 .serverCertificateHasUnknownRoot,
                 .serverCertificateNotYetValid,
                 .serverCertificateUntrusted,
                 .clientCertificateRejected,
                 .clientCertificateRequired:
                return L10n.string("validation.tls_failed")
            default:
                return error.localizedDescription
            }
        }

        return error.localizedDescription
    }
}
