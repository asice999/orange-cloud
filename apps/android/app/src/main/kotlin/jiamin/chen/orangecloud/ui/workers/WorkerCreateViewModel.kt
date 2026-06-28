package jiamin.chen.orangecloud.ui.workers

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import jiamin.chen.orangecloud.core.auth.AuthRepository
import jiamin.chen.orangecloud.core.auth.Scopes
import jiamin.chen.orangecloud.data.repository.AccountStore
import jiamin.chen.orangecloud.data.repository.WorkerRepository
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate
import javax.inject.Inject

sealed interface WorkerCreateEvent {
    data object Created : WorkerCreateEvent
    data class Error(val message: String?) : WorkerCreateEvent
}

@HiltViewModel
class WorkerCreateViewModel @Inject constructor(
    private val accountStore: AccountStore,
    private val workerRepository: WorkerRepository,
    authRepository: AuthRepository,
) : ViewModel() {

    val canWrite: Boolean = authRepository.hasScope(Scopes.WORKERS_WRITE)
    val defaultCompatibilityDate: String = LocalDate.now().toString() // yyyy-MM-dd

    private val _isUploading = MutableStateFlow(false)
    val isUploading: StateFlow<Boolean> = _isUploading.asStateFlow()

    private val eventChannel = Channel<WorkerCreateEvent>(Channel.BUFFERED)
    val events: Flow<WorkerCreateEvent> = eventChannel.receiveAsFlow()

    /** Worker 名：小写字母/数字开头，其后可含小写字母/数字/连字符/下划线（对齐 iOS）。 */
    fun isValidName(name: String): Boolean = name.matches(Regex("^[a-z0-9][a-z0-9_-]*$"))

    fun create(name: String, code: String, compatibilityDate: String) {
        if (!canWrite || _isUploading.value) return
        if (!isValidName(name) || code.isBlank()) return
        _isUploading.update { true }
        viewModelScope.launch {
            try {
                accountStore.ensureLoaded()
                val accountId = accountStore.selectedAccountId.value ?: error("no account")
                workerRepository.deployScript(accountId, name, code, compatibilityDate.ifBlank { defaultCompatibilityDate })
                eventChannel.send(WorkerCreateEvent.Created)
            } catch (e: Exception) {
                eventChannel.send(WorkerCreateEvent.Error(e.message))
            } finally {
                _isUploading.update { false }
            }
        }
    }
}
