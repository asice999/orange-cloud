package jiamin.chen.orangecloud.data.repository

import jiamin.chen.orangecloud.core.network.CfApiClient
import jiamin.chen.orangecloud.data.local.WorkerDao
import jiamin.chen.orangecloud.data.local.toEntity
import jiamin.chen.orangecloud.data.local.toWorker
import jiamin.chen.orangecloud.data.model.WorkerBindingInput
import jiamin.chen.orangecloud.data.model.WorkerCustomDomain
import jiamin.chen.orangecloud.data.model.WorkerCustomDomainInput
import jiamin.chen.orangecloud.data.model.WorkerRoute
import jiamin.chen.orangecloud.data.model.WorkerRouteInput
import jiamin.chen.orangecloud.data.model.WorkerSchedule
import jiamin.chen.orangecloud.data.model.WorkerSchedulesResult
import jiamin.chen.orangecloud.data.model.WorkerScheduleInput
import jiamin.chen.orangecloud.data.model.WorkerScript
import jiamin.chen.orangecloud.data.model.WorkerSecret
import jiamin.chen.orangecloud.data.model.WorkerSecretInput
import jiamin.chen.orangecloud.data.model.WorkerSettings
import jiamin.chen.orangecloud.data.model.WorkerSettingsPatch
import jiamin.chen.orangecloud.data.model.WorkerSubdomain
import jiamin.chen.orangecloud.data.model.WorkerSubdomainInput
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Workers 仓库：Room 为单一可信源，列表刷新后整账号替换缓存（对应 iOS WorkerService + CacheSync）。
 * 脚本配置（变量/密钥/触发器/域名）为会话级即时数据，不入 Room。该列表端点不分页。
 */
@Singleton
class WorkerRepository @Inject constructor(
    private val api: CfApiClient,
    private val workerDao: WorkerDao,
    private val json: Json,
) {
    fun observeWorkers(accountId: String): Flow<List<WorkerScript>> =
        workerDao.observeByAccount(accountId).map { rows -> rows.map { it.toWorker() } }

    suspend fun refreshWorkers(accountId: String) {
        val scripts = api.getList<WorkerScript>("accounts/$accountId/workers/scripts").items
        workerDao.replaceForAccount(accountId, scripts.map { it.toEntity(accountId) })
    }

    /**
     * 新建 / 覆盖一个 module Worker（粘贴的 JS 代码）。PUT 脚本 = multipart（metadata + worker.js 模块）。
     * 对应 iOS WorkerService.deployScript。注意：读取现有源码端点 /content 在 OAuth 下被封（cf-10405），
     * 故只支持「提供新代码」创建/覆盖，不预填现有代码。成功后刷新 Room 列表。
     */
    suspend fun deployScript(accountId: String, name: String, code: String, compatibilityDate: String) {
        val metadata = """{"main_module":"worker.js","compatibility_date":"$compatibilityDate","bindings":[]}"""
        api.putMultipartFile<kotlinx.serialization.json.JsonElement>(
            "accounts/$accountId/workers/scripts/$name",
            metadata, "worker.js", code, "application/javascript+module",
        )
        refreshWorkers(accountId)
    }

    // MARK: - 设置（绑定 / 变量）

    /** 脚本设置（绑定 + 兼容性日期/标志）。 */
    suspend fun settings(accountId: String, scriptName: String): WorkerSettings =
        api.get("accounts/$accountId/workers/scripts/$scriptName/settings")

    /**
     * 改绑定（变量）：传入完整新 bindings（变更项为实体，其余 inherit），PATCH settings 不动代码。
     * CF 要求 settings 作为 multipart form part。
     */
    suspend fun patchSettings(accountId: String, scriptName: String, bindings: List<WorkerBindingInput>, settings: WorkerSettings) {
        val patch = WorkerSettingsPatch(
            bindings = bindings,
            compatibilityDate = settings.compatibilityDate,
            compatibilityFlags = settings.compatibilityFlags,
        )
        api.requestMultipartJsonChecked(
            method = "PATCH",
            path = "accounts/$accountId/workers/scripts/$scriptName/settings",
            partName = "settings",
            bodyJson = json.encodeToString(WorkerSettingsPatch.serializer(), patch),
        )
    }

    // MARK: - 密钥

    /** 密钥列表（仅名 + 类型，永不含值）。 */
    suspend fun listSecrets(accountId: String, scriptName: String): List<WorkerSecret> =
        api.getList<WorkerSecret>("accounts/$accountId/workers/scripts/$scriptName/secrets").items

    /** 新建 / 更新密钥。 */
    suspend fun putSecret(accountId: String, scriptName: String, name: String, text: String) =
        api.putChecked("accounts/$accountId/workers/scripts/$scriptName/secrets", WorkerSecretInput(name, text))

    /** 删除密钥。 */
    suspend fun deleteSecret(accountId: String, scriptName: String, name: String) =
        api.delete("accounts/$accountId/workers/scripts/$scriptName/secrets/$name")

    // MARK: - Cron 触发器

    suspend fun schedules(accountId: String, scriptName: String): List<WorkerSchedule> =
        api.get<WorkerSchedulesResult>("accounts/$accountId/workers/scripts/$scriptName/schedules").schedules

    /** 整组替换 Cron（请求体是裸数组 [{cron}]；漏传即删）。 */
    suspend fun putSchedules(accountId: String, scriptName: String, crons: List<String>) =
        api.putChecked("accounts/$accountId/workers/scripts/$scriptName/schedules", crons.map { WorkerScheduleInput(it) })

    // MARK: - 域名 / 路由

    /** workers.dev 子域状态。 */
    suspend fun subdomain(accountId: String, scriptName: String): WorkerSubdomain =
        api.get("accounts/$accountId/workers/scripts/$scriptName/subdomain")

    /** 切换 workers.dev 子域。 */
    suspend fun setSubdomain(accountId: String, scriptName: String, enabled: Boolean) =
        api.postChecked("accounts/$accountId/workers/scripts/$scriptName/subdomain", WorkerSubdomainInput(enabled))

    /** 该脚本的自定义域（按 service 过滤）。 */
    suspend fun customDomains(accountId: String, scriptName: String): List<WorkerCustomDomain> =
        api.getList<WorkerCustomDomain>("accounts/$accountId/workers/domains", listOf("service" to scriptName)).items

    /** 挂载自定义域到该脚本。 */
    suspend fun attachDomain(accountId: String, scriptName: String, hostname: String, zoneId: String) =
        api.putChecked("accounts/$accountId/workers/domains", WorkerCustomDomainInput(hostname, scriptName, zoneId))

    /** 卸载自定义域。 */
    suspend fun deleteDomain(accountId: String, domainId: String) =
        api.delete("accounts/$accountId/workers/domains/$domainId")

    /** zone 下全部 Worker 路由（调用方按 script 过滤到本脚本）。 */
    suspend fun routes(zoneId: String): List<WorkerRoute> =
        api.getList<WorkerRoute>("zones/$zoneId/workers/routes").items

    /** 新建路由（pattern → script）。 */
    suspend fun createRoute(zoneId: String, pattern: String, scriptName: String) =
        api.postChecked("zones/$zoneId/workers/routes", WorkerRouteInput(pattern, scriptName))

    /** 删除路由。 */
    suspend fun deleteRoute(zoneId: String, routeId: String) =
        api.delete("zones/$zoneId/workers/routes/$routeId")
}
