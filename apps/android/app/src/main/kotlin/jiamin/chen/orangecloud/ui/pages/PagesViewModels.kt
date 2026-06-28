package jiamin.chen.orangecloud.ui.pages

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import jiamin.chen.orangecloud.core.auth.AuthRepository
import jiamin.chen.orangecloud.core.auth.Scopes
import jiamin.chen.orangecloud.data.model.PagesBuildConfig
import jiamin.chen.orangecloud.data.model.PagesDeployment
import jiamin.chen.orangecloud.data.model.PagesProject
import jiamin.chen.orangecloud.data.model.PagesProjectUpdate
import jiamin.chen.orangecloud.data.repository.AccountStore
import jiamin.chen.orangecloud.data.repository.PagesRepository
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

// MARK: - 项目列表（account 级）

@HiltViewModel
class PagesListViewModel @Inject constructor(
    private val accountStore: AccountStore,
    private val repository: PagesRepository,
    authRepository: AuthRepository,
) : StorageListViewModel<PagesProject>(accountStore, authRepository.hasScope(Scopes.PAGES_READ)) {
    val canWrite: Boolean = authRepository.hasScope(Scopes.PAGES_WRITE)
    private val _busy = MutableStateFlow(false)
    val busy: StateFlow<Boolean> = _busy.asStateFlow()
    private val eventChannel = Channel<String>(Channel.BUFFERED)
    val errors: Flow<String> = eventChannel.receiveAsFlow()
    override suspend fun fetch(accountId: String): List<PagesProject> = repository.listProjects(accountId)
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

    fun create(name: String, productionBranch: String) = op { repository.createProject(it, name, productionBranch.ifBlank { "main" }) }
    fun delete(project: PagesProject) = op { repository.deleteProject(it, project.name) }
}

// MARK: - 项目详情 + 部署

sealed interface PagesEvent {
    data object Retried : PagesEvent
    data object RolledBack : PagesEvent
    data class Error(val message: String?) : PagesEvent
}

data class PagesDetailUiState(
    val projectName: String = "",
    val project: PagesProject? = null,
    val deployments: List<PagesDeployment> = emptyList(),
    val isLoading: Boolean = false,
    val busyDeploymentId: String? = null,
    val missingScope: Boolean = false,
    val canWrite: Boolean = false,
    val hasError: Boolean = false,
)

@HiltViewModel
class PagesDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val accountStore: AccountStore,
    private val repository: PagesRepository,
    authRepository: AuthRepository,
) : ViewModel() {

    private val projectName: String = checkNotNull(savedStateHandle["project"])
    private val hasRead = authRepository.hasScope(Scopes.PAGES_READ)
    private val canWrite = authRepository.hasScope(Scopes.PAGES_WRITE)

    private val _uiState = MutableStateFlow(
        PagesDetailUiState(projectName = projectName, isLoading = hasRead, missingScope = !hasRead, canWrite = canWrite),
    )
    val uiState: StateFlow<PagesDetailUiState> = _uiState.asStateFlow()

    private val eventChannel = Channel<PagesEvent>(Channel.BUFFERED)
    val events: Flow<PagesEvent> = eventChannel.receiveAsFlow()

    init { if (hasRead) load() }

    fun load() {
        if (!hasRead) return
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, hasError = false) }
            try {
                accountStore.ensureLoaded()
                val accountId = accountStore.selectedAccountId.value ?: error("no account")
                val project = repository.getProject(accountId, projectName)
                val deployments = repository.listDeployments(accountId, projectName)
                _uiState.update { it.copy(project = project, deployments = deployments) }
            } catch (e: Exception) {
                _uiState.update { it.copy(hasError = true) }
            } finally {
                _uiState.update { it.copy(isLoading = false) }
            }
        }
    }

    fun retry(deployment: PagesDeployment) = mutate(deployment) { accountId ->
        repository.retryDeployment(accountId, projectName, deployment.id)
        eventChannel.send(PagesEvent.Retried)
    }

    fun rollback(deployment: PagesDeployment) = mutate(deployment) { accountId ->
        repository.rollbackDeployment(accountId, projectName, deployment.id)
        eventChannel.send(PagesEvent.RolledBack)
    }

    /** 编辑构建配置（构建命令 / 输出目录 / 根目录）。 */
    fun updateBuildConfig(buildCommand: String, destinationDir: String, rootDir: String) {
        if (!canWrite || _uiState.value.busyDeploymentId != null) return
        _uiState.update { it.copy(busyDeploymentId = "config") }
        viewModelScope.launch {
            try {
                val accountId = accountStore.selectedAccountId.value ?: error("no account")
                val cfg = PagesBuildConfig(
                    buildCommand = buildCommand.ifBlank { null },
                    destinationDir = destinationDir.ifBlank { null },
                    rootDir = rootDir.ifBlank { null },
                )
                repository.updateProject(accountId, projectName, PagesProjectUpdate(buildConfig = cfg))
                eventChannel.send(PagesEvent.Retried)
                load()
            } catch (e: Exception) {
                eventChannel.send(PagesEvent.Error(e.message))
            } finally {
                _uiState.update { it.copy(busyDeploymentId = null) }
            }
        }
    }

    private inline fun mutate(deployment: PagesDeployment, crossinline action: suspend (String) -> Unit) {
        if (!canWrite || _uiState.value.busyDeploymentId != null) return
        _uiState.update { it.copy(busyDeploymentId = deployment.id) }
        viewModelScope.launch {
            try {
                val accountId = accountStore.selectedAccountId.value ?: error("no account")
                action(accountId)
                load()
            } catch (e: Exception) {
                eventChannel.send(PagesEvent.Error(e.message))
            } finally {
                _uiState.update { it.copy(busyDeploymentId = null) }
            }
        }
    }
}
