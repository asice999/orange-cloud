//
//  WorkersAIService.swift
//  Orange Cloud
//
//  Workers AI（account 级）。模型目录浏览 ai.read；文本生成试运行需 ai.read + ai.write。
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

    /// 文本生成试运行（POST /accounts/{id}/ai/run/{model}）。model 形如 `@cf/meta/llama-3.1-8b-instruct`，
    /// 其中的 `/` `@` `.` `-` 都是合法 path 字符，percentEncodedPath 无需额外编码。返回生成文本。
    func runTextGeneration(accountId: String, model: String, messages: [AIChatMessage]) async throws -> String {
        let response: CFAPIResponse<AITextGenResult> = try await client.post(
            "accounts/\(accountId)/ai/run/\(model)", body: AITextGenRequest(messages: messages)
        )
        guard response.success, let result = response.result else { throw response.toAPIError() }
        return result.response ?? ""
    }
}
