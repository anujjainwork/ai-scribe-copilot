import Foundation

class ApiService {
    static let shared = ApiService()
    
    private init() {}
    
    // MARK: - Ping Server (GET, no body)
    func pingServer(completion: @escaping (Result<String, Error>) -> Void) {
        ApiClient.shared.makeRequest(endpoint: "ping") { result in
            switch result {
            case .success(let data):
                completion(.success(String(data: data, encoding: .utf8) ?? ""))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Upload Session
    func uploadSession(request: SessionUploadRequest, completion: @escaping (Result<ApiResponse, Error>) -> Void) {
        ApiClient.shared.makeRequest(endpoint: "v1/upload-session", method: "POST", body: request) { result in
            switch result {
            case .success(let data):
                do {
                    let response = try JSONDecoder().decode(ApiResponse.self, from: data)
                    completion(.success(response))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Get Presigned URL
    func getPresignedUrl(request: ChunkUploadRequest, completion: @escaping (Result<PresignedUrlResponse, Error>) -> Void) {
        ApiClient.shared.makeRequest(endpoint: "v1/get-presigned-url", method: "POST", body: request) { result in
            switch result {
            case .success(let data):
                do {
                    let response = try JSONDecoder().decode(PresignedUrlResponse.self, from: data)
                    completion(.success(response))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Upload Chunk to Presigned URL
    func uploadChunkToUrl(url: String, fileBytes: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: url) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = fileBytes
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
        task.resume()
    }
    
    // MARK: - Notify Chunk Uploaded
    func notifyChunkUploaded(request: ChunkUploadNotificationRequest, completion: @escaping (Result<ApiResponse, Error>) -> Void) {
        ApiClient.shared.makeRequest(endpoint: "v1/notify-chunk-uploaded", method: "POST", body: request) { result in
            switch result {
            case .success(let data):
                do {
                    let response = try JSONDecoder().decode(ApiResponse.self, from: data)
                    completion(.success(response))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
