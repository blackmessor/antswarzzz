import Foundation

class APIService {
    static let shared = APIService()
    var baseURL = "http://10.0.0.31:8080"

    private let decoder = JSONDecoder()

    // MARK: - Public API

    func register(username: String) async throws -> RegisterResponse {
        let data = try await postData("/api/player/register", body: ["username": username])
        // Server may return an error response (e.g. duplicate username) with HTTP 200
        if let err = try? decoder.decode(ErrorResponse.self, from: data), err.error != nil {
            throw APIError.server(err.error!)
        }
        return try decoder.decode(RegisterResponse.self, from: data)
    }

    func getColony(_ id: Int) async throws -> ColonyStateResponse {
        let data = try await get("/api/colony/\(id)")
        if let err = try? decoder.decode(ErrorResponse.self, from: data), err.error != nil {
            throw APIError.server(err.error!)
        }
        return try decoder.decode(ColonyStateResponse.self, from: data)
    }

    func assignWorkers(colonyID: Int, food: Int, materials: Int) async throws -> ActionResponse {
        let body: [String: Any] = [
            "action": "assign_workers",
            "workers_on_food": food,
            "workers_on_materials": materials
        ]
        let data = try await postData("/api/colony/\(colonyID)", body: body)
        return try decoder.decode(ActionResponse.self, from: data)
    }

    func forceTick(colonyID: Int) async throws -> ActionResponse {
        let data = try await postData("/api/tick", body: ["colony_id": colonyID])
        return try decoder.decode(ActionResponse.self, from: data)
    }

    func post(_ path: String, body: [String: Any]) async throws -> ActionResponse {
        let data = try await postData(path, body: body)
        return try decoder.decode(ActionResponse.self, from: data)
    }

    // MARK: - HTTP

    private func get(_ path: String) async throws -> Data {
        let url = URL(string: baseURL + path)!
        print("[API] GET \(url.absoluteString)")
        let (data, resp) = try await URLSession.shared.data(from: url)
        if let http = resp as? HTTPURLResponse {
            print("[API] GET \(path) → \(http.statusCode), \(data.count) bytes")
            guard http.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw APIError.http(http.statusCode, body)
            }
        }
        return data
    }

    private func postData(_ path: String, body: [String: Any]) async throws -> Data {
        let url = URL(string: baseURL + path)!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        print("[API] POST \(url.absoluteString) body=\(body)")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse {
            print("[API] POST \(path) → \(http.statusCode), \(data.count) bytes")
            guard http.statusCode == 200 else {
                let bodyStr = String(data: data, encoding: .utf8) ?? ""
                throw APIError.http(http.statusCode, bodyStr)
            }
        }
        return data
    }
}

// MARK: - Error response from server

struct ErrorResponse: Codable {
    let error: String?
}

enum APIError: LocalizedError {
    case server(String)
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .server(let msg): return msg
        case .http(let code, let body): return "HTTP \(code): \(body)"
        }
    }
}