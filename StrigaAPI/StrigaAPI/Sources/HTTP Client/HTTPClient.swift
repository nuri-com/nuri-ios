import Foundation

protocol HTTPClientDelegate: AnyObject {
    func headers(for request: URLRequest, body: Data?) -> [String: String]
}

final class HTTPClient {

    // MARK: - Dependencies

    private let urlSession = URLSession(configuration: .default)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Variables

    var host: String = ""
    weak var delegate: HTTPClientDelegate?

    // MARK: - Public

    func get<O: Decodable>(url: URL) async throws -> O {
        var request = urlRequest(for: url, method: "GET")
        if let headers = delegate?.headers(for: request, body: nil) {
            request.addHeaders(headers)
        }
        return try await data(for: request)
    }

    func post<I: Encodable, O: Decodable>(url: URL, input: I) async throws -> O {
        var request = urlRequest(for: url, method: "POST")
        let body = try encoder.encode(input)
        request.httpBody = body
        if let headers = delegate?.headers(for: request, body: body) {
            request.addHeaders(headers)
        }
        return try await data(for: request)
    }

    // MARK: - Private

    private func data<O: Decodable>(for request: URLRequest) async throws -> O {
        let (data, response) = try await urlSession.data(for: request)
        return try parseResponse(for: data, response: response)
    }

    private func parseResponse<O: Decodable>(for data: Data, response: URLResponse) throws -> O {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        switch httpResponse.statusCode {
        case 200..<300:
            return try decoder.decode(O.self, from: data)
        default:
            if let error = try? decoder.decode(ErrorResponse.self, from: data) {
                throw error
            } else if let error = try? decoder.decode(ValidationErrorResponse.self, from: data) {
                throw error
            } else {
                if let string = String(data: data, encoding: .utf8) {
                    print("[Striga] \(string)")
                } else {
                    print("[Striga] Unknown error")
                }
                throw URLError(.init(rawValue: httpResponse.statusCode))
            }
        }
    }

    private func urlRequest(for url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        return request
    }
}

private extension URLRequest {

    mutating func addHeaders(_ headers: [String: String]) {
        headers.forEach { key, value in
            addValue(value, forHTTPHeaderField: key)
        }
    }
}
