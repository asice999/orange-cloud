package jiamin.chen.orangecloud.data.repository

import jiamin.chen.orangecloud.core.network.CfApiClient
import jiamin.chen.orangecloud.data.model.AIChatMessage
import jiamin.chen.orangecloud.data.model.AIGateway
import jiamin.chen.orangecloud.data.model.AIModel
import jiamin.chen.orangecloud.data.model.AITextGenRequest
import jiamin.chen.orangecloud.data.model.AITextGenResult
import jiamin.chen.orangecloud.data.model.AIGatewayCreate
import jiamin.chen.orangecloud.data.model.CFQueue
import jiamin.chen.orangecloud.data.model.CFQueueCreate
import jiamin.chen.orangecloud.data.model.CFQueuePurge
import jiamin.chen.orangecloud.data.model.CFQueueUpdate
import jiamin.chen.orangecloud.data.model.DurableObjectNamespace
import jiamin.chen.orangecloud.data.model.HyperdriveConfig
import jiamin.chen.orangecloud.data.model.HyperdriveCreate
import jiamin.chen.orangecloud.data.model.HyperdrivePatch
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 开发者平台只读模块（account 级）：Queues / AI Gateway / Durable Objects / Workers AI / Hyperdrive。
 * 对应 iOS QueueService / AIGatewayService / DurableObjectService / WorkersAIService / HyperdriveService。
 */
@Singleton
class DeveloperPlatformRepository @Inject constructor(
    private val api: CfApiClient,
) {
    suspend fun listQueues(accountId: String): List<CFQueue> =
        api.get("accounts/$accountId/queues")

    suspend fun createQueue(accountId: String, name: String): CFQueue =
        api.post("accounts/$accountId/queues", CFQueueCreate(name))

    suspend fun updateQueue(accountId: String, queueId: String, body: CFQueueUpdate): CFQueue =
        api.put("accounts/$accountId/queues/$queueId", body)

    suspend fun purgeQueue(accountId: String, queueId: String) =
        api.postChecked("accounts/$accountId/queues/$queueId/purge", CFQueuePurge(true))

    suspend fun deleteQueue(accountId: String, queueId: String) =
        api.delete("accounts/$accountId/queues/$queueId")

    suspend fun listGateways(accountId: String): List<AIGateway> =
        api.get("accounts/$accountId/ai-gateway/gateways")

    suspend fun createGateway(accountId: String, body: AIGatewayCreate): AIGateway =
        api.post("accounts/$accountId/ai-gateway/gateways", body)

    suspend fun deleteGateway(accountId: String, gatewayId: String) =
        api.delete("accounts/$accountId/ai-gateway/gateways/$gatewayId")

    suspend fun listDurableObjectNamespaces(accountId: String): List<DurableObjectNamespace> =
        api.get("accounts/$accountId/workers/durable_objects/namespaces")

    suspend fun listHyperdrive(accountId: String): List<HyperdriveConfig> =
        api.get("accounts/$accountId/hyperdrive/configs")

    suspend fun createHyperdrive(accountId: String, body: HyperdriveCreate): HyperdriveConfig =
        api.post("accounts/$accountId/hyperdrive/configs", body)

    suspend fun updateHyperdrive(accountId: String, configId: String, body: HyperdrivePatch): HyperdriveConfig =
        api.patch("accounts/$accountId/hyperdrive/configs/$configId", body)

    suspend fun deleteHyperdrive(accountId: String, configId: String) =
        api.delete("accounts/$accountId/hyperdrive/configs/$configId")

    suspend fun listAIModels(accountId: String): List<AIModel> =
        api.getList<AIModel>("accounts/$accountId/ai/models/search", listOf("per_page" to "100")).items

    /** 文本生成试运行（POST /accounts/{id}/ai/run/{model}）。model 含 @cf/ 前缀，作 path 段直拼。 */
    suspend fun runTextGeneration(accountId: String, model: String, messages: List<AIChatMessage>): String {
        val result: AITextGenResult = api.post(
            "accounts/$accountId/ai/run/$model", AITextGenRequest(messages),
        )
        return result.response ?: ""
    }
}
