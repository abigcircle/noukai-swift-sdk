import Foundation

/// Test-only `URLProtocol` subclass that intercepts HTTP requests and
/// returns scripted responses. Set `responseData`, `responseStatusCode`,
/// and/or `responseError` before the call, then inspect `lastRequest`
/// after. Uses shared static state — all tests that use this MUST run
/// inside a single `@Suite(.serialized)` to avoid data races.
final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseData: Data = Data()
    nonisolated(unsafe) static var responseStatusCode: Int = 200
    nonisolated(unsafe) static var responseError: Error?
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var allRequests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        Self.allRequests.append(request)

        let capturedError = Self.responseError
        let capturedStatusCode = Self.responseStatusCode
        let capturedData = Self.responseData
        let capturedURL = request.url!

        // Dispatch asynchronously to avoid potential deadlocks when URLSession
        // calls startLoading on a thread that is also awaiting the response.
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }

            if let error = capturedError {
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }

            let response = HTTPURLResponse(
                url: capturedURL,
                statusCode: capturedStatusCode,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!

            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: capturedData)
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    static func reset() {
        responseData = Data()
        responseStatusCode = 200
        responseError = nil
        lastRequest = nil
        allRequests = []
    }
}
