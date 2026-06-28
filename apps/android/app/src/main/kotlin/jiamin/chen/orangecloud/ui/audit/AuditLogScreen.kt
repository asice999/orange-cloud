package jiamin.chen.orangecloud.ui.audit

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.background
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.History
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.derivedStateOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import jiamin.chen.orangecloud.R
import jiamin.chen.orangecloud.core.design.SkyBackground
import jiamin.chen.orangecloud.core.design.SkyEmptyState
import jiamin.chen.orangecloud.core.design.SkyHeader
import jiamin.chen.orangecloud.core.design.onSky
import jiamin.chen.orangecloud.core.design.rememberSkyPhase
import jiamin.chen.orangecloud.core.design.theme.OcSuccess
import jiamin.chen.orangecloud.data.model.AuditLogEntry
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

private val auditFormatter: DateTimeFormatter =
    DateTimeFormatter.ofPattern("MM-dd HH:mm", Locale.getDefault()).withZone(ZoneId.systemDefault())

@Composable
fun AuditLogScreen(
    onBack: () -> Unit,
    viewModel: AuditLogViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val phase = rememberSkyPhase()
    val onSky = phase.onSky
    val listState = rememberLazyListState()

    val shouldLoadMore by remember {
        derivedStateOf {
            val last = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            last >= state.entries.size - 3 && state.hasMore && !state.isLoadingMore
        }
    }
    LaunchedEffect(shouldLoadMore) { if (shouldLoadMore) viewModel.loadMore() }

    SkyBackground(phase = phase) {
        Column(Modifier.fillMaxSize().systemBarsPadding()) {
            SkyHeader(
                title = stringResource(R.string.audit_title),
                onSky = onSky,
                isLoading = state.isLoading,
                onRefresh = { viewModel.loadFirst() },
                onBack = onBack,
                titleSize = 22,
                backDescription = stringResource(R.string.common_back),
                refreshDescription = stringResource(R.string.common_refresh),
            )
            when {
                state.missingScope ->
                    SkyEmptyState(Icons.Outlined.Lock, stringResource(R.string.scope_missing), onSky, stringResource(R.string.common_refresh)) { viewModel.loadFirst() }

                state.entries.isEmpty() && state.isLoading ->
                    Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator(color = onSky) }

                state.entries.isEmpty() && state.hasError ->
                    SkyEmptyState(Icons.Outlined.History, stringResource(R.string.error_generic), onSky, stringResource(R.string.common_refresh)) { viewModel.loadFirst() }

                state.entries.isEmpty() ->
                    SkyEmptyState(Icons.Outlined.History, stringResource(R.string.audit_empty), onSky, stringResource(R.string.common_refresh)) { viewModel.loadFirst() }

                else -> LazyColumn(
                    state = listState,
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(state.entries, key = { it.id ?: it.hashCode().toString() }) { entry ->
                        AuditRow(entry)
                    }
                    if (state.isLoadingMore) {
                        item {
                            Box(Modifier.fillMaxWidth().padding(16.dp), Alignment.Center) {
                                CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.dp, color = onSky)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AuditRow(entry: AuditLogEntry) {
    Surface(color = MaterialTheme.colorScheme.surfaceContainerLow, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.Top) {
            val ok = entry.succeeded
            val dotColor = when (ok) {
                true -> OcSuccess
                false -> Color(0xFFE5484D)
                null -> MaterialTheme.colorScheme.outline
            }
            Box(Modifier.padding(top = 5.dp).size(8.dp).background(dotColor, CircleShape))
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(
                    entry.action?.description?.takeIf { it.isNotBlank() }
                        ?: entry.action?.type
                        ?: stringResource(R.string.audit_unknown_action),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                val parts = buildList {
                    entry.actor?.email?.takeIf { it.isNotBlank() }?.let { add(it) }
                    entry.resource?.type?.takeIf { it.isNotBlank() }?.let { add(it) }
                }
                if (parts.isNotEmpty()) {
                    Text(
                        parts.joinToString(" · "),
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                entry.timestampMillis?.let { ms ->
                    Text(
                        auditFormatter.format(Instant.ofEpochMilli(ms)),
                        fontSize = 11.sp,
                        fontFamily = FontFamily.Monospace,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}
