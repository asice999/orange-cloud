package jiamin.chen.orangecloud.ui.devplatform

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import jiamin.chen.orangecloud.core.auth.AuthRepository
import jiamin.chen.orangecloud.core.auth.Scopes
import jiamin.chen.orangecloud.data.model.AIChatMessage
import jiamin.chen.orangecloud.data.model.AIGateway
import jiamin.chen.orangecloud.data.model.AIGatewayCreate
import jiamin.chen.orangecloud.data.model.AIModel
import jiamin.chen.orangecloud.data.model.CFQueue
import jiamin.chen.orangecloud.data.model.CFQueueSettingsPatch
import jiamin.chen.orangecloud.data.model.CFQueueUpdate
import jiamin.chen.orangecloud.data.model.DurableObjectNamespace
import jiamin.chen.orangecloud.data.model.HyperdriveCachingPatch
import jiamin.chen.orangecloud.data.model.HyperdriveConfig
import jiamin.chen.orangecloud.data.model.HyperdriveCreate
import jiamin.chen.orangecloud.data.model.HyperdriveCreateOrigin
import jiamin.chen.orangecloud.data.model.HyperdrivePatch
import jiamin.chen.orangecloud.data.repository.AccountStore
import jiamin.chen.orangecloud.data.repository.DeveloperPlatformRepository
import jiamin.chen.orangecloud.ui.storage.StorageListViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

// MARK: - 只读列表 VM

@HiltViewModel
class QueuesViewModel @Inject constructor(
    private val accountStore: AccountStore,
    private val repository: DeveloperPlatformRepository,
    authRepository: AuthRepository,
) : StorageListViewModel<CFQueue>(accountStore, authRepository.hasScope(Scopes.QUEUES_READ)) {
    val canWrite: Boolean = authRepository.hasScope(Scopes.QUEUES_WRITE)
    private val _busy = MutableStateFlow(false)
    val busy: StateFlow<Boolean> = _busy.asStateFlow()
    private val eventChannel = Channel<String>(Channel.BUFFERED)
    val errors: Flow<String> = eventChannel.receiveAsFlow()
    override suspend fun fetch(accountId: String): List<CFQueue> = repository.listQueues(accountId)
    init { load() }

    private fun op(block: suspend (String) -> Unit) {
        if (!canWrite || _busy.value) return
        _busy.update { true }
        viewModelScope.launch {
            try {
                val acct = accountStore.selectedAccountId.value ?: error("no account")
                block(acct); load()
            } catch (e: Exception) {
                eventChannel.send(e.message ?: "")
            } finally {
                _busy.update { false }
            }
        }
    }

    fun create(name: String) = op { repository.createQueue(it, name) }
    fun delete(queue: CFQueue) = op { repository.deleteQueue(it, queue.queueId) }
    fun purge(queue: CFQueue) = op { repository.purgeQueue(it, queue.queueId) }
    fun togglePause(queue: CFQueue, paused: Boolean) = op {
        repository.updateQueue(it, queue.queueId, CFQueueUpdate(settings = CFQueueSettingsPatch(deliveryPaused = paused)))
    }
}

@HiltViewModel
class AIGatewayViewModel @Inject constructor(
    private val accountStore: AccountStore,
    private val repository: DeveloperPlatformRepository,
    authRepository: AuthRepository,
) : StorageListViewModel<AIGateway>(accountStore, authRepository.hasScope(Scopes.AIG_READ)) {
    val canWrite: Boolean = authRepository.hasScope(Scopes.AIG_WRITE)
    private val _busy = MutableStateFlow(false)
    val busy: StateFlow<Boolean> = _busy.asStateFlow()
    private val eventChannel = Channel<String>(Channel.BUFFERED)
    val errors: Flow<String> = eventChannel.receiveAsFlow()
    override suspend fun fetch(accountId: String): List<AIGateway> = repository.listGateways(accountId)
    init { load() }

    private fun op(block: suspend (String) -> Unit) {
        if (!canWrite || _busy.value) return
        _busy.update { true }
        viewModelScope.launch {
            try {
                val acct = accountStore.selectedAccountId.value ?: error("no account")
                block(acct); load()
            } catch (e: Exception) {
                eventChannel.send(e.message ?: "")
            } finally {
                _busy.update { false }
            }
        }
    }

    /** 用默认设置建网关（id 必填，其余给合理默认；对齐 iOS create 表单可改的字段）。 */
    fun create(id: String, cacheTtl: Int, rateLimit: Int, collectLogs: Boolean) = op {
        repository.createGateway(
            it,
            AIGatewayCreate(
                id = id,
                cacheInvalidateOnUpdate = false,
                cacheTtl = cacheTtl,
                collectLogs = collectLogs,
                rateLimitingInterval = 60,
                rateLimitingLimit = rateLimit,
            ),
        )
    }
    fun delete(gateway: AIGateway) = op { repository.deleteGateway(it, gateway.id) }
}

@HiltViewModel
class DurableObjectsViewModel @Inject constructor(
    accountStore: AccountStore,
    private val repository: DeveloperPlatformRepository,
    authRepository: AuthRepository,
) : StorageListViewModel<DurableObjectNamespace>(accountStore, authRepository.hasScope(Scopes.WORKERS_READ)) {
    override suspend fun fetch(accountId: String): List<DurableObjectNamespace> = repository.listDurableObjectNamespaces(accountId)
    init { load() }
}

@HiltViewModel
class HyperdriveViewModel @Inject constructor(
    private val accountStore: AccountStore,
    private val repository: DeveloperPlatformRepository,
    authRepository: AuthRepository,
) : StorageListViewModel<HyperdriveConfig>(accountStore, authRepository.hasScope(Scopes.HYPERDRIVE_READ)) {
    val canWrite: Boolean = authRepository.hasScope(Scopes.HYPERDRIVE_WRITE)
    private val _busy = MutableStateFlow(false)
    val busy: StateFlow<Boolean> = _busy.asStateFlow()
    private val eventChannel = Channel<String>(Channel.BUFFERED)
    val errors: Flow<String> = eventChannel.receiveAsFlow()
    override suspend fun fetch(accountId: String): List<HyperdriveConfig> = repository.listHyperdrive(accountId)
    init { load() }

    private fun op(block: suspend (String) -> Unit) {
        if (!canWrite || _busy.value) return
        _busy.update { true }
        viewModelScope.launch {
            try {
                val acct = accountStore.selectedAccountId.value ?: error("no account")
                block(acct); load()
            } catch (e: Exception) {
                eventChannel.send(e.message ?: "")
            } finally {
                _busy.update { false }
            }
        }
    }

    fun create(name: String, scheme: String, host: String, port: Int, database: String, user: String, password: String) = op {
        repository.createHyperdrive(
            it,
            HyperdriveCreate(name, HyperdriveCreateOrigin(scheme, host, port, database, user, password)),
        )
    }
    fun delete(config: HyperdriveConfig) = op { repository.deleteHyperdrive(it, config.id) }

    /** 切换查询缓存开关（enabled=true → caching.disabled=false）。 */
    fun toggleCaching(config: HyperdriveConfig, enabled: Boolean) = op {
        repository.updateHyperdrive(it, config.id, HyperdrivePatch(caching = HyperdriveCachingPatch(disabled = !enabled)))
    }
}

@HiltViewModel
class WorkersAIViewModel @Inject constructor(
    accountStore: AccountStore,
    private val repository: DeveloperPlatformRepository,
    authRepository: AuthRepository,
) : StorageListViewModel<AIModel>(accountStore, authRepository.hasScope(Scopes.AI_READ)) {
    /** 能跑文本生成试运行（需写权限）。 */
    val canRun: Boolean = authRepository.hasScope(Scopes.AI_WRITE)
    override suspend fun fetch(accountId: String): List<AIModel> = repository.listAIModels(accountId)
    init { load() }
}

// MARK: - Workers AI 文本生成试运行

data class AIRunUiState(
    val model: String = "",
    val task: String = "",
    val description: String = "",
    val canRun: Boolean = false,
    val prompt: String = "",
    val response: String = "",
    val isRunning: Boolean = false,
    val error: String? = null,
) {
    /** 仅文本生成模型可在 App 内试运行（输入/输出契约与 iOS 一致）。 */
    val isTextGen: Boolean get() = task.contains("Text Generation", ignoreCase = true)
}

@HiltViewModel
class AIRunViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val accountStore: AccountStore,
    private val repository: DeveloperPlatformRepository,
    authRepository: AuthRepository,
) : ViewModel() {

    private val model: String = checkNotNull(savedStateHandle["model"])

    private val _uiState = MutableStateFlow(
        AIRunUiState(
            model = model,
            task = savedStateHandle.get<String>("task").orEmpty(),
            description = savedStateHandle.get<String>("desc").orEmpty(),
            canRun = authRepository.hasScope(Scopes.AI_WRITE),
        ),
    )
    val uiState: StateFlow<AIRunUiState> = _uiState.asStateFlow()

    fun updatePrompt(text: String) = _uiState.update { it.copy(prompt = text) }

    fun run() {
        val prompt = _uiState.value.prompt
        if (prompt.isBlank() || _uiState.value.isRunning) return
        _uiState.update { it.copy(isRunning = true, error = null, response = "") }
        viewModelScope.launch {
            try {
                accountStore.ensureLoaded()
                val accountId = accountStore.selectedAccountId.value ?: error("no account")
                val messages = listOf(AIChatMessage(role = "user", content = prompt))
                val response = repository.runTextGeneration(accountId, model, messages)
                _uiState.update { it.copy(response = response) }
            } catch (e: Exception) {
                _uiState.update { it.copy(error = e.message ?: "error") }
            } finally {
                _uiState.update { it.copy(isRunning = false) }
            }
        }
    }
}
