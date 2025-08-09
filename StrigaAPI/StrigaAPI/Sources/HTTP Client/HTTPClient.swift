import Foundation

protocol HTTPClientDelegate: AnyObject {
    func headers(for request: URLRequest, body: Data?) -> [String: String]
}

final class HTTPClient {

    // MARK: - Dependencies

    private let urlSession: URLSession = {
        var config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120 // 2 minutes timeout for sandbox
        config.timeoutIntervalForResource = 120 // 2 minutes timeout
        return URLSession(configuration: config)
    }()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()
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

    func post<I: Encodable>(url: URL, input: I) async throws {
        try await data(for: try request(url: url, input: input))
    }

    func post<I: Encodable, O: Decodable>(url: URL, input: I) async throws -> O {
        return try await data(for: try request(url: url, input: input))
    }

    // MARK: - Private

    private func request<I: Encodable>(url: URL, input: I) throws -> URLRequest {
        var request = urlRequest(for: url, method: "POST")
        let body = try encoder.encode(input)
        request.httpBody = body
        if let string = String(data: body, encoding: .utf8) {
            print("[Lukas] Input: \(string)")
        }

        if let headers = delegate?.headers(for: request, body: body) {
            request.addHeaders(headers)
        }
        return request
    }

    private func data<O: Decodable>(for request: URLRequest) async throws -> O {
        print("[HTTPClient] Making request to: \(request.url?.absoluteString ?? "nil")")
        print("[HTTPClient] Method: \(request.httpMethod ?? "nil")")
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("[HTTPClient] Body: \(bodyString)")
        }
        
        let (data, response) = try await urlSession.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("[HTTPClient] Response status: \(httpResponse.statusCode)")
        }
        if let responseString = String(data: data, encoding: .utf8) {
            print("[HTTPClient] Response data: \(responseString)")
        }
        
        return try parseResponse(for: data, response: response)
    }

    private func data(for request: URLRequest) async throws {
        let (data, response) = try await urlSession.data(for: request)
        try parseResponse(for: data, response: response)
    }

    private func parseResponse(for data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        switch httpResponse.statusCode {
        case 200..<300:
            break
        default:
            print("[HTTPClient] ❌ Error response with status: \(httpResponse.statusCode)")
            if let string = String(data: data, encoding: .utf8) {
                print("[HTTPClient] Error response body: \(string)")
            }
            
            if let error = try? decoder.decode(ErrorResponse.self, from: data) {
                print("[HTTPClient] Decoded as ErrorResponse: \(error)")
                throw error
            } else if let error = try? decoder.decode(ValidationErrorResponse.self, from: data) {
                print("[HTTPClient] Decoded as ValidationErrorResponse: \(error)")
                throw error
            } else {
                print("[HTTPClient] Could not decode error response, throwing URLError")
                throw URLError(.init(rawValue: httpResponse.statusCode))
            }
        }
    }

    private func parseResponse<O: Decodable>(for data: Data, response: URLResponse) throws -> O {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        switch httpResponse.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(O.self, from: data)
            } catch {
                if let string = String(data: data, encoding: .utf8) {
                    print("[Lukas] \(string)")
                }
                throw error
            }
        default:
            print("[HTTPClient] ❌ Error response with status: \(httpResponse.statusCode)")
            if let string = String(data: data, encoding: .utf8) {
                print("[HTTPClient] Error response body: \(string)")
            }
            
            if let error = try? decoder.decode(ErrorResponse.self, from: data) {
                print("[HTTPClient] Decoded as ErrorResponse: \(error)")
                throw error
            } else if let error = try? decoder.decode(ValidationErrorResponse.self, from: data) {
                print("[HTTPClient] Decoded as ValidationErrorResponse: \(error)")
                throw error
            } else {
                print("[HTTPClient] Could not decode error response, throwing URLError")
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
