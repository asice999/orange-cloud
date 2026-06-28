package jiamin.chen.orangecloud.ui.audit

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import jiamin.chen.orangecloud.core.auth.AuthRepository
import jiamin.chen.orangecloud.core.auth.Scopes
import jiamin.chen.orangecloud.data.model.AuditLogEntry
import jiamin.chen.orangecloud.data.repository.AccountStore
import jiamin.chen.orangecloud.data.repository.AuditLogRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.temporal.ChronoUnit
import javax.inject.Inject

data class AuditLogUiState(
    val entries: List<AuditLogEntry> = emptyList(),
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val hasError: Boolean = false,
    val missingScope: Boolean = false,
    val hasMore: Boolean = false,
)

@HiltViewModel
class AuditLogViewModel @Inject constructor(
    private val accountStore: AccountStore,
    private val repository: AuditLogRepository,
    authRepository: AuthRepository,
) : ViewModel() {

    // 审计日志只需账号必选 scope（account-settings.read），通常恒有。
    private val hasScope = authRepository.hasScope(Scopes.ACCOUNT_READ)
    private var cursor: String? = null

    private val _uiState = MutableStateFlow(
        AuditLogUiState(isLoading = hasScope, missingScope = !hasScope),
    )
    val uiState: StateFlow<AuditLogUiState> = _uiState.asStateFlow()

    init {
        if (hasScope) loadFirst()
    }

    fun loadFirst() {
        if (!hasScope) return
        cursor = null
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, hasError = false, entries = emptyList()) }
            fetchPage(reset = true)
            _uiState.update { it.copy(isLoading = false) }
        }
    }

    fun loadMore() {
        if (!hasScope || cursor == null || _uiState.value.isLoadingMore) return
        viewModelScope.launch {
            _uiState.update { it.copy(isLoadingMore = true) }
            fetchPage(reset = false)
            _uiState.update { it.copy(isLoadingMore = false) }
        }
    }

    private suspend fun fetchPage(reset: Boolean) {
        try {
            accountStore.ensureLoaded()
            val accountId = accountStore.selectedAccountId.value ?: run {
                _uiState.update { it.copy(hasError = true) }
                return
            }
            val before = Instant.now()
            val since = before.minus(30, ChronoUnit.DAYS)
            val page = repository.list(accountId, since, before, cursor)
            cursor = page.cursor
            val entries = page.result.orEmpty()
            _uiState.update {
                it.copy(
                    entries = if (reset) entries else it.entries + entries,
                    hasMore = !page.cursor.isNullOrEmpty() && entries.isNotEmpty(),
                )
            }
        } catch (e: Exception) {
            _uiState.update { it.copy(hasError = true) }
        }
    }
}
