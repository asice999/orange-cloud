//
//  CFAPIClient.swift
//  Orange Cloud
//
//  所有 Cloudflare API 调用的统一入口：
//  自动注入 Bearer Token、过期前主动刷新、401 刷新后重试一次、统一错误解析。
//

import Foundation

actor CFAPIClient {

    private let baseURL = URL(string: "https://api.cloudflare.com/client/v4")!
    private let session = URLSession.shared
    private let authManager: AuthManager

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    // MARK: - 核心请求方法

    func get<T: Codable & Sendable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        try await request(method: "GET", path: path, queryItems: queryItems, body: nil)
    }

    func post<T: Codable & Sendable, B: Codable & Sendable>(_ path: String, body: B) async throws -> T {
        let data = try JSONEncoder().encode(body)
        return try await request(method: "POST", path: path, queryItems: [], body: data)
    }

    func put<T: Codable & Sendable, B: Codable & Sendable>(_ path: String, body: B) async throws -> T {
        let data = try JSONEncoder().encode(body)
        return try await request(method: "PUT", path: path, queryItems: [], body: data)
    }

    func patch<T: Codable & Sendable, B: Codable & Sendable>(_ path: String, body: B) async throws -> T {
        let data = try JSONEncoder().encode(body)
        return try await request(method: "PATCH", path: path, queryItems: [], body: data)
    }

    func delete(_ path: String) async throws {
        let _: EmptyResponse = try await request(method: "DELETE", path: path, queryItems: [], body: nil)
    }

    /// 返回原始响应体（KV value 等非 JSON 信封端点）
    func getRaw(_ path: String, queryItems: [URLQueryItem] = []) async throws -> Data {
        try await performRequest(method: "GET", path: path, queryItems: queryItems, body: nil, contentType: nil).0
    }

    /// 原始响应体 + HTTP 响应（需读 Content-Type 的 boundary，如 Worker 源码 multipart）
    func getRawResponse(_ path: String, queryItems: [URLQueryItem] = []) async throws -> (Data, HTTPURLResponse) {
        try await performRequest(method: "GET", path: path, queryItems: queryItems, body: nil, contentType: nil)
    }

    /// 原始字节 PUT（R2 对象上传等），自带 Content-Type
    func putRaw<T: Codable & Sendable>(_ path: String, body: Data, contentType: String) async throws -> T {
        let (data, _) = try await performRequest(
            method: "PUT", path: path, queryItems: [], body: body, contentType: contentType
        )
        return try Self.decode(data, path: path)
    }

    /// multipart/form-data 写入（KV 写值要求 value + metadata 两个 part）
    func putMultipart<T: Codable & Sendable>(_ path: String, fields: [String: String]) async throws -> T {
        let boundary = "OrangeCloud-\(UUID().uuidString)"
        var body = Data()
        for (name, value) in fields {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
            body.append(Data("\(value)\r\n".utf8))
        }
        body.append(Data("--\(boundary)--\r\n".utf8))

        let (data, _) = try await performRequest(
            method: "PUT", path: path, queryItems: [], body: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        return try Self.decode(data, path: path)
    }

    /// multipart/form-data 写入带文件 part（Snippets 上传 JS 模块）。
    /// metadata part 为 JSON（如 {"main_module":"snippet.js"}）；文件 part 的字段名即文件名，
    /// 与 main_module 引用一致，Content-Type 由调用方给（JS 模块用 application/javascript+module）。
    func putMultipartFile<T: Codable & Sendable>(
        _ path: String,
        metadata: [String: String],
        fileName: String,
        fileContent: Data,
        fileContentType: String
    ) async throws -> T {
        let boundary = "OrangeCloud-\(UUID().uuidString)"
        var body = Data()

        // metadata part
        let metadataJSON = try JSONEncoder().encode(metadata)
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"metadata\"\r\n".utf8))
        body.append(Data("Content-Type: application/json\r\n\r\n".utf8))
        body.append(metadataJSON)
        body.append(Data("\r\n".utf8))

        // 文件 part（字段名 = filename = fileName，main_module 引用它）
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(fileName)\"; filename=\"\(fileName)\"\r\n".utf8))
        body.append(Data("Content-Type: \(fileContentType)\r\n\r\n".utf8))
        body.append(fileContent)
        body.append(Data("\r\n".utf8))

        body.append(Data("--\(boundary)--\r\n".utf8))

        let (data, _) = try await performRequest(
            method: "PUT", path: path, queryItems: [], body: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        return try Self.decode(data, path: path)
    }

    /// 通用 multipart 请求：一个 JSON part（metadata / settings）+ 可选单个文件 part，支持 method 与 query。
    /// Worker 上传（PUT，metadata + 模块文件，带 ?bindings_inherit=strict）与改设置（PATCH，settings）共用。
    func multipartRequest<T: Codable & Sendable, M: Encodable & Sendable>(
        method: String,
        _ path: String,
        queryItems: [URLQueryItem] = [],
        jsonPartName: String,
        jsonPart: M,
        file: (name: String, contentType: String, content: Data)? = nil
    ) async throws -> T {
        let boundary = "OrangeCloud-\(UUID().uuidString)"
        var body = Data()

        // JSON part（metadata / settings）
        let json = try JSONEncoder().encode(jsonPart)
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(jsonPartName)\"\r\n".utf8))
        body.append(Data("Content-Type: application/json\r\n\r\n".utf8))
        body.append(json)
        body.append(Data("\r\n".utf8))

        // 可选文件 part（脚本模块；字段名 = filename，main_module/body_part 引用它）
        if let file {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.name)\"\r\n".utf8))
            body.append(Data("Content-Type: \(file.contentType)\r\n\r\n".utf8))
            body.append(file.content)
            body.append(Data("\r\n".utf8))
        }

        body.append(Data("--\(boundary)--\r\n".utf8))

        let (data, _) = try await performRequest(
            method: method, path: path, queryItems: queryItems, body: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        return try Self.decode(data, path: path, method: method)
    }

    /// GraphQL Analytics API。信封是 {data, errors}（GraphQL 错误时 HTTP 仍为 200），
    /// 与 REST 的 {result, success} 不同。复用 request 自动获得 Token 刷新与 401 重试。
    func graphQL<D: Codable & Sendable, V: Codable & Sendable>(
        query: String,
        variables: V
    ) async throws -> D {
        let body = try JSONEncoder().encode(GraphQLRequest(query: query, variables: variables))
        let envelope: GraphQLResponse<D> = try await request(
            method: "POST", path: "graphql", queryItems: [], body: body
        )
        if let first = envelope.errors?.first {
            // GraphQL 错误时 HTTP 仍为 200——网络层只看状态码看不到这层，这里单独记，
            // 便于排查「请求 200 但数据没出来」（如数据集权限/字段不可用）。
            AppLog.network.error("graphQL error (\(envelope.errors?.count ?? 1)): \(first.message)")
            // authz（账户级数据集未授权）单独抛——调用方据此降级到「免费账号无账户级数据」态，
            // 并停发同账号其余注定失败的账户级查询。
            if envelope.errors?.contains(where: \.isAuthz) == true {
#if OPENSOURCE_UNLOCKED
                // ====== 自编译版：返回部分数据 ======
                // Cloudflare GraphQL 可在部分字段 authz 时仍返回其余字段数据
                // （如 Free 账号 month 窗口不可用但 today 窗口正常）。
                // 数据非空时返回部分结果，避免因单字段 authz 丢弃全部数据。
                if let data = envelope.data {
                    return data
                }
#endif
                throw APIError.accountNotAuthorized
            }
            throw APIError.cloudflareError(code: 0, message: first.message)
        }
        guard let data = envelope.data else {
            throw APIError.decodingError(URLError(.cannotDecodeContentData))
        }
        return data
    }

    // MARK: - 内部实现

    private func request<T: Codable & Sendable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem],
        body: Data?
    ) async throws -> T {
        let (data, _) = try await performRequest(
            method: method, path: path, queryItems: queryItems, body: body, contentType: "application/json"
        )
        return try Self.decode(data, path: path, method: method)
    }

    /// 统一的 HTTP 执行：Token 注入与刷新、401 重试一次、HTTP 错误映射，返回原始 Data + 响应
    private func performRequest(
        method: String,
        path: String,
        queryItems: [URLQueryItem],
        body: Data?,
        contentType: String?,
        isRetry: Bool = false
    ) async throws -> (Data, HTTPURLResponse) {

        // 1. 检查 Token 是否临期，如需则先刷新
        let token = try await validAccessToken()

        // 2. 构造请求。path 视为已编码（KV key 等特殊字符由调用方预先百分号编码，
        //    不能用 appendingPathComponent——它会把 % 二次编码）
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.percentEncodedPath += "/" + path
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = method
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let contentType {
            urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        urlRequest.httpBody = body

        // 3. 执行请求
        let start = Date()
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            AppLog.network.error("\(method) /\(Self.logPath(path)) network error: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            AppLog.network.error("\(method) /\(Self.logPath(path)) bad response (not HTTP)")
            throw APIError.networkError(URLError(.badServerResponse))
        }

        let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)

        // 4. 401：Token 过期，刷新后重试一次
        if http.statusCode == 401 && !isRetry {
            AppLog.network.notice("\(method) /\(Self.logPath(path)) -> 401, refresh & retry")
            _ = try await authManager.refreshAccessToken()
            return try await performRequest(
                method: method, path: path, queryItems: queryItems,
                body: body, contentType: contentType, isRetry: true
            )
        }

        // 结果各记一行（2xx → info 带响应体大小；其余 → error 带 CF 业务错误码/消息），便于排查
        if (200...299).contains(http.statusCode) {
            AppLog.network.info("\(method) /\(Self.logPath(path)) -> \(http.statusCode) (\(elapsedMs)ms, \(Self.sizeLabel(data.count)))")
        } else {
            AppLog.network.error("\(method) /\(Self.logPath(path)) -> \(http.statusCode) (\(elapsedMs)ms)\(Self.cfErrorSummary(data))")
        }

        // 5. HTTP 错误处理（优先透出 CF 返回的业务错误信息）
        switch http.statusCode {
        case 200...299:
            return (data, http)
        case 401:
            throw APIError.unauthorized
        case 429:
            throw APIError.rateLimited
        default:
            if let envelope = try? JSONDecoder().decode(CFAPIResponse<EmptyResponse>.self, from: data),
               let first = envelope.errors.first {
                throw APIError.cloudflareError(code: first.code, message: first.message)
            }
            switch http.statusCode {
            case 403:       throw APIError.forbidden
            case 404:       throw APIError.notFound
            case 500...599: throw APIError.serverError(statusCode: http.statusCode)
            default:        throw APIError.serverError(statusCode: http.statusCode)
            }
        }
    }

    /// 返回当前身份的有效 Token（临期则先刷新）
    private func validAccessToken() async throws -> String {
        guard let token = await authManager.currentToken else {
            throw APIError.unauthorized
        }
        let valid: String
        if token.expiresAt.timeIntervalSinceNow < 60 {  // 提前 60 秒刷新
            do {
                valid = try await authManager.refreshAccessToken()
            } catch AuthError.notLoggedIn {
                throw APIError.unauthorized          // 刷新令牌确已失效：不再使用旧 token
            } catch {
                // 刷新瞬时失败但旧 token 仍在有效期内：先用旧 token，真过期了由 401 重试兜底
                if token.expiresAt.timeIntervalSinceNow > 0 {
                    valid = token.accessToken
                } else {
                    throw error
                }
            }
        } else {
            valid = token.accessToken
        }
        return valid
    }

    /// 日志用路径：截断，避免把超长 KV key 等用户数据完整写进日志
    private static func logPath(_ path: String) -> String {
        path.count > 80 ? String(path.prefix(80)) + "…" : path
    }

    // MARK: - 解码与诊断（统一记日志，绝不写入数据值，仅字段路径/错误码）

    /// 统一 JSON 解码：失败时记一行（含失败字段路径与类型，不含数据值）再抛 decodingError。
    /// 「请求 200 但数据没出来」多半在这里现形。
    private static func decode<T: Decodable>(_ data: Data, path: String, method: String = "PUT") throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            AppLog.network.error("\(method) /\(logPath(path)) decode \(T.self) failed: \(decodeErrorSummary(error))")
            throw APIError.decodingError(error)
        }
    }

    /// 把 DecodingError 浓缩成一句（字段名是 API schema，非用户隐私，可记）
    private static func decodeErrorSummary(_ error: Error) -> String {
        guard let de = error as? DecodingError else { return error.localizedDescription }
        switch de {
        case .keyNotFound(let key, let ctx):    return "missing '\(key.stringValue)' at [\(codingPath(ctx))]"
        case .typeMismatch(let type, let ctx):  return "type mismatch \(type) at [\(codingPath(ctx))]"
        case .valueNotFound(let type, let ctx): return "null \(type) at [\(codingPath(ctx))]"
        case .dataCorrupted(let ctx):           return "corrupted at [\(codingPath(ctx))]"
        @unknown default:                       return "decoding error"
        }
    }

    private static func codingPath(_ ctx: DecodingError.Context) -> String {
        ctx.codingPath.map(\.stringValue).joined(separator: ".")
    }

    /// 非 2xx 时尽力解出 CF 业务错误码/消息（消息是接口级文案，非用户隐私）；解不出返回空串。
    private static func cfErrorSummary(_ data: Data) -> String {
        guard let env = try? JSONDecoder().decode(CFAPIResponse<EmptyResponse>.self, from: data),
              let first = env.errors.first else { return "" }
        return " cf=\(first.code) \(first.message)"
    }

    /// 响应体大小（便于发现「200 但空结果」）
    private static func sizeLabel(_ bytes: Int) -> String {
        bytes < 1024 ? "\(bytes)B" : String(format: "%.1fKB", Double(bytes) / 1024)
    }
}
