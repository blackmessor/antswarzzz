import Foundation

class APIService {
    static let shared = APIService()
    var baseURL = "http://10.0.0.31:8080"

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    func register(username: String) async throws -> RegisterResponse {
        let body = ["username": username]
        let data = try await post("/api/player/register", body: body)
        return try decoder.decode(RegisterResponse.self, from: data)
    }

    func getColony(_ id: Int) async throws -> ColonyStateResponse {
        let data = try await get("/api/colony/\(id)")
        return try decoder.decode(ColonyStateResponse.self, from: data)
    }

    func assignWorkers(colonyID: Int, food: Int, materials: Int) async throws -> ActionResponse {
        let body: [String: Any] = [
            "action": "assign_workers",
            "workers_on_food": food,
            "workers_on_materials": materials
        ]
        let data = try await post("/api/colony/\(colonyID)", body: body)
        return try decoder.decode(ActionResponse.self, from: data)
    }

    func forceTick(colonyID: Int) async throws -> ActionResponse {
        let body: [String: Any] = ["colony_id": colonyID]
        let data = try await post("/api/tick", body: body)
        return try decoder.decode(ActionResponse.self, from: data)
    }

    // MARK: - HTTP helpers

    private func get(_ path: String) async throws -> Data {
        guard let url = URL(string: baseURL + path) else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private func post(_ path: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: baseURL + path) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
