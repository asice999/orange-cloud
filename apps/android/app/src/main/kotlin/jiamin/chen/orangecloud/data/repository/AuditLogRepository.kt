package jiamin.chen.orangecloud.data.repository

import jiamin.chen.orangecloud.core.network.ApiError
import jiamin.chen.orangecloud.core.network.CfApiClient
import jiamin.chen.orangecloud.data.model.AuditLogPage
import kotlinx.serialization.json.Json
import java.time.Instant
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 账号审计日志（Audit Logs v2）只读查询，游标分页。对应 iOS AuditLogService。
 * since / before 为必填时间窗；direction=desc 取最近在前。仅需 account-settings.read。
 * 单独用宽松 Json 解码（v2 的 result_info.count 是字符串，靠 ignoreUnknownKeys 跳过）。
 */
@Singleton
class AuditLogRepository @Inject constructor(
    private val api: CfApiClient,
) {
    private val json = Json { ignoreUnknownKeys = true; coerceInputValues = true }

    /** 拉取一页审计日志。cursor 为空取首页，非空续接下一页。 */
    suspend fun list(
        accountId: String,
        since: Instant,
        before: Instant,
        cursor: String?,
        limit: Int = 50,
    ): AuditLogPage {
        val query = buildList {
            add("since" to since.toString())
            add("before" to before.toString())
            add("limit" to limit.toString())
            add("direction" to "desc")
            if (!cursor.isNullOrEmpty()) add("cursor" to cursor)
        }
        val bytes = api.getRaw("accounts/$accountId/logs/audit", query)
        val page = runCatching { json.decodeFromString(AuditLogPage.serializer(), bytes.decodeToString()) }
            .getOrElse { throw ApiError.Decoding(it) }
        if (!page.success) {
            throw ApiError.Cloudflare(page.errors.orEmpty().map { ApiError.CfError(it.code, it.message) })
        }
        return page
    }
}
