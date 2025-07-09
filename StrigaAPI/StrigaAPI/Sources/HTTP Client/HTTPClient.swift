import Foundation

final class HTTPClient {

    // MARK: - Dependencies

    private let urlSession = URLSession(configuration: .default)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Variables

    var host: String = ""
    var additionalHeaders: [String: String] = [:]

    // MARK: - Public

    func get<O: Decodable>(url: URL) async throws -> O {
        var request = try urlRequest(for: url, method: "GET")
        return try await data(for: request)
    }

    func post<I: Encodable, O: Decodable>(url: URL, input: I) async throws -> O {
        var request = try urlRequest(for: url, method: "POST")
        request.httpBody = try encoder.encode(input)
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
        case 300...:
            throw URLError(.init(rawValue: httpResponse.statusCode))
        default:
            throw URLError(.unknown)
        }
    }

    private func urlRequest(for url: URL, method: String) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        var headers = additionalHeaders
        headers["Content-Type"] = "application/json"
        headers.forEach { key, value in
            request.addValue(value, forHTTPHeaderField: key)
        }
        return request
    }
}
