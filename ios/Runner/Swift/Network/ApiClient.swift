import Foundation

class ApiClient {
    static let shared = ApiClient()
    private let baseURL = "https://753be50e-0ede-423d-8da4-f7bf2fb6497d.mock.pstmn.io/"
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }
    
    /// Generic request function for Codable bodies
    func makeRequest<T: Codable>(endpoint: String,
                                 method: String = "GET",
                                 body: T? = nil,
                                 completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = URL(string: baseURL + endpoint) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = method

        // Encode body only if it exists
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                completion(.failure(error))
                return
            }
        }
        
        let task = session.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
            } else if let data = data {
                completion(.success(data))
            }
        }
        task.resume()
    }
    
    /// Overload for requests with no body
    func makeRequest(endpoint: String,
                     method: String = "GET",
                     completion: @escaping (Result<Data, Error>) -> Void) {
        makeRequest(endpoint: endpoint, method: method, body: Optional<EmptyRequest>.none, completion: completion)
    }
}

/// Dummy struct to satisfy generic `T` when no body is required
struct EmptyRequest: Codable {}
