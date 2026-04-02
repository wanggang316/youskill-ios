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
                    return message.isEmpty ? "请求格式无效，请检查 BASE_URL 或 Model。" : message
                case 401, 403:
                    return message.isEmpty ? "API Key 无效，或当前账号没有访问该模型的权限。" : message
                case 404:
                    return message.isEmpty ? "接口路径不存在，请确认 BASE_URL 是否为 OpenAI-compatible 地址。" : message
                case 429:
                    return message.isEmpty ? "请求过于频繁，或当前账户额度不足。" : message
                default:
                    return message.isEmpty ? "服务端返回错误：\(code)" : message
                }
            case .invalidResponse:
                return "服务端响应格式异常。"
            case .emptyResponse:
                return "服务端返回了空响应。"
            }
        }

        if let error = error as? URLError {
            switch error.code {
            case .timedOut:
                return "连接超时，请检查网络、代理、VPN，或确认 BASE_URL 是否可达。"
            case .notConnectedToInternet:
                return "当前网络不可用。"
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return "无法连接到服务器，请检查 BASE_URL。"
            case .networkConnectionLost:
                return "网络连接已中断，请稍后重试。"
            case .secureConnectionFailed,
                 .serverCertificateHasBadDate,
                 .serverCertificateHasUnknownRoot,
                 .serverCertificateNotYetValid,
                 .serverCertificateUntrusted,
                 .clientCertificateRejected,
                 .clientCertificateRequired:
                return "TLS/证书握手失败，请检查代理、VPN、系统证书或 HTTPS 配置。"
            default:
                return error.localizedDescription
            }
        }

        return error.localizedDescription
    }
}
