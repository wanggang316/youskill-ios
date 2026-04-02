import Foundation

final class MockURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)
    private nonisolated(unsafe) static var requestHandlers: [String: Handler] = [:]
    private static let lock = NSLock()

    static func register(url: String, handler: @escaping Handler) {
        lock.lock()
        requestHandlers[url] = handler
        lock.unlock()
    }

    private static func handler(for url: String) -> Handler? {
        lock.lock()
        defer { lock.unlock() }
        return requestHandlers[url]
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url?.absoluteString,
              let handler = MockURLProtocol.handler(for: url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
