//
//  WorkersAIService.swift
//  Orange Cloud
//
//  Workers AI（account 级）。模型目录只读浏览，ai.read。
//

import Foundation

struct WorkersAIService {

    private let client: CFAPIClient

    init(client: CFAPIClient) { self.client = client }

    /// 可用模型目录（GET /accounts/{id}/ai/models/search，按页拉满 per_page）
    func listModels(accountId: String) async throws -> [AIModel] {
        let response: CFAPIResponseArray<AIModel> = try await client.get(
            "accounts/\(accountId)/ai/models/search",
            queryItems: [URLQueryItem(name: "per_page", value: "100")]
        )
        guard response.success else { throw response.toAPIError() }
        return response.result ?? []
    }
}
