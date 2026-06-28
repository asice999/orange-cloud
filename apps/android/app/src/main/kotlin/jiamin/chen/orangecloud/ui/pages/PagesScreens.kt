package jiamin.chen.orangecloud.ui.pages

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.CloudUpload
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.outlined.InsertDriveFile
import androidx.compose.material.icons.outlined.Language
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.Restore
import androidx.compose.material.icons.outlined.Web
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
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
import jiamin.chen.orangecloud.core.design.StatusDot
import jiamin.chen.orangecloud.core.design.onSky
import jiamin.chen.orangecloud.core.design.rememberSkyPhase
import jiamin.chen.orangecloud.core.design.theme.OcOrange
import jiamin.chen.orangecloud.core.design.theme.OcSuccess
import jiamin.chen.orangecloud.data.model.PagesDeployment
import jiamin.chen.orangecloud.data.model.PagesProject
import jiamin.chen.orangecloud.ui.storage.StorageListBody
import jiamin.chen.orangecloud.ui.storage.StorageRow

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PagesListScreen(
    onBack: () -> Unit,
    onOpenProject: (String) -> Unit,
    viewModel: PagesListViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val busy by viewModel.busy.collectAsStateWithLifecycle()
    val phase = rememberSkyPhase()
    val onSky = phase.onSky
    val snackbar = remember { SnackbarHostState() }
    var showCreate by remember { mutableStateOf(false) }
    var toDelete by remember { mutableStateOf<PagesProject?>(null) }
    LaunchedEffect(Unit) { viewModel.errors.collect { snackbar.showSnackbar(it) } }

    SkyBackground(phase = phase) {
        Box(Modifier.fillMaxSize()) {
            Column(Modifier.fillMaxSize().systemBarsPadding()) {
                SkyHeader(
                    title = stringResource(R.string.pages_title),
                    onSky = onSky,
                    isLoading = state.isLoading || busy,
                    onRefresh = { viewModel.load() },
                    onBack = onBack,
                    titleSize = 22,
                    backDescription = stringResource(R.string.common_back),
                    refreshDescription = stringResource(R.string.common_refresh),
                )
                StorageListBody(
                    state = state,
                    onSky = onSky,
                    emptyIcon = Icons.Outlined.Web,
                    emptyText = stringResource(R.string.pages_empty),
                    onRetry = { viewModel.load() },
                ) { project ->
                    ProjectRow(
                        project,
                        onClick = { onOpenProject(project.name) },
                        onLongClick = if (viewModel.canWrite) ({ toDelete = project }) else null,
                    )
                }
            }
            if (viewModel.canWrite && !state.missingScope) {
                FloatingActionButton(
                    onClick = { showCreate = true },
                    containerColor = OcOrange,
                    contentColor = Color.White,
                    modifier = Modifier.align(Alignment.BottomEnd).padding(20.dp).systemBarsPadding(),
                ) { Icon(Icons.Outlined.Add, contentDescription = stringResource(R.string.pages_create)) }
            }
            SnackbarHost(snackbar, Modifier.align(Alignment.BottomCenter).systemBarsPadding())
        }
    }

    if (showCreate) {
        ModalBottomSheet(onDismissRequest = { if (!busy) showCreate = false }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
            PagesCreateForm(isSaving = busy) { name, branch -> viewModel.create(name, branch); showCreate = false }
        }
    }
    toDelete?.let { p ->
        AlertDialog(
            onDismissRequest = { toDelete = null },
            title = { Text(stringResource(R.string.pages_delete_title)) },
            text = { Text(p.name) },
            confirmButton = { TextButton(onClick = { viewModel.delete(p); toDelete = null }) { Text(stringResource(R.string.dns_delete), color = Color(0xFFE5484D)) } },
            dismissButton = { TextButton(onClick = { toDelete = null }) { Text(stringResource(R.string.common_cancel)) } },
        )
    }
}

@Composable
private fun PagesCreateForm(isSaving: Boolean, onSave: (name: String, branch: String) -> Unit) {
    var name by rememberSaveable { mutableStateOf("") }
    var branch by rememberSaveable { mutableStateOf("main") }
    val canSave = name.matches(Regex("^[a-z0-9-]+$")) && !isSaving
    Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(stringResource(R.string.pages_create), fontSize = 18.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
        OutlinedTextField(name, { name = it.lowercase() }, label = { Text(stringResource(R.string.pages_field_name)) }, singleLine = true, modifier = Modifier.fillMaxWidth())
        Text(stringResource(R.string.pages_name_hint), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        OutlinedTextField(branch, { branch = it }, label = { Text(stringResource(R.string.pages_field_branch)) }, singleLine = true, modifier = Modifier.fillMaxWidth())
        Button(onClick = { onSave(name, branch) }, enabled = canSave, colors = ButtonDefaults.buttonColors(containerColor = OcOrange, contentColor = Color.White), modifier = Modifier.fillMaxWidth()) {
            if (isSaving) { CircularProgressIndicator(Modifier.height(18.dp).width(18.dp), strokeWidth = 2.dp, color = Color.White); Spacer(Modifier.width(8.dp)) }
            Text(stringResource(R.string.dns_save))
        }
    }
}

@Composable
private fun ProjectRow(project: PagesProject, onClick: () -> Unit, onLongClick: (() -> Unit)? = null) {
    val sub = project.latestDeployment?.let { stringResource(deployStatusLabel(it.statusRaw)) }
        ?: project.source?.config?.repoLabel
        ?: project.subdomain
    StorageRow(
        icon = Icons.Outlined.Web,
        title = project.name,
        subtitle = sub,
        onClick = onClick,
        onLongClick = onLongClick,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PagesProjectDetailScreen(
    onBack: () -> Unit,
    viewModel: PagesDetailViewModel = hiltViewModel(),
    deployViewModel: PagesDeployViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val deploy by deployViewModel.uiState.collectAsStateWithLifecycle()
    val phase = rememberSkyPhase()
    val onSky = phase.onSky
    val snackbarHostState = remember { SnackbarHostState() }
    var showConfig by remember { mutableStateOf(false) }
    var showDeployChooser by remember { mutableStateOf(false) }
    var pendingZip by remember { mutableStateOf(false) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) deployViewModel.deployFrom(uri, pendingZip)
    }

    val retriedMsg = stringResource(R.string.pages_retried)
    val rolledMsg = stringResource(R.string.pages_rolled_back)
    val deployedMsg = stringResource(R.string.pages_deployed)
    LaunchedEffect(Unit) {
        viewModel.events.collect { event ->
            when (event) {
                PagesEvent.Retried -> snackbarHostState.showSnackbar(retriedMsg)
                PagesEvent.RolledBack -> snackbarHostState.showSnackbar(rolledMsg)
                is PagesEvent.Error -> snackbarHostState.showSnackbar(event.message ?: "")
            }
        }
    }
    LaunchedEffect(Unit) {
        deployViewModel.events.collect { snackbarHostState.showSnackbar(deployedMsg); viewModel.load() }
    }
    LaunchedEffect(deploy.error) { deploy.error?.let { snackbarHostState.showSnackbar(it) } }

    SkyBackground(phase = phase) {
        Box(Modifier.fillMaxSize()) {
            Column(Modifier.fillMaxSize().systemBarsPadding()) {
                SkyHeader(
                    title = state.projectName,
                    onSky = onSky,
                    isLoading = state.isLoading,
                    onRefresh = { viewModel.load() },
                    onBack = onBack,
                    titleSize = 22,
                    backDescription = stringResource(R.string.common_back),
                    refreshDescription = stringResource(R.string.common_refresh),
                )
                when {
                    state.missingScope ->
                        SkyEmptyState(Icons.Outlined.Lock, stringResource(R.string.scope_missing), onSky, stringResource(R.string.common_refresh)) { viewModel.load() }
                    state.project == null && state.isLoading ->
                        Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator(color = onSky) }
                    else -> LazyColumn(
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        state.project?.let { item { ProjectInfoCard(it) } }
                        if (state.canWrite) {
                            item {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    TextButton(onClick = { showConfig = true }, enabled = !deploy.isBusy) {
                                        Icon(Icons.Outlined.Edit, contentDescription = null, tint = OcOrange, modifier = Modifier.width(16.dp))
                                        Spacer(Modifier.width(6.dp))
                                        Text(stringResource(R.string.pages_edit_build), color = OcOrange)
                                    }
                                    TextButton(onClick = { showDeployChooser = true }, enabled = !deploy.isBusy) {
                                        Icon(Icons.Outlined.CloudUpload, contentDescription = null, tint = OcOrange, modifier = Modifier.width(16.dp))
                                        Spacer(Modifier.width(6.dp))
                                        Text(stringResource(R.string.pages_deploy_code), color = OcOrange)
                                    }
                                }
                            }
                        }
                        if (deploy.isBusy) {
                            item {
                                Surface(color = OcOrange.copy(alpha = 0.10f), shape = RoundedCornerShape(12.dp), modifier = Modifier.fillMaxWidth()) {
                                    Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                                        CircularProgressIndicator(Modifier.width(20.dp), strokeWidth = 2.dp, color = OcOrange)
                                        Spacer(Modifier.width(12.dp))
                                        Text(
                                            if (deploy.phase == DeployPhase.PREPARING) stringResource(R.string.pages_deploy_preparing)
                                            else stringResource(R.string.pages_deploy_progress, deploy.uploaded, deploy.total),
                                            fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface,
                                        )
                                    }
                                }
                            }
                        }
                        item {
                            Text(stringResource(R.string.pages_deployments), color = onSky, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(start = 4.dp, top = 8.dp))
                        }
                        items(state.deployments, key = { it.id }) { dep ->
                            DeploymentRow(
                                dep,
                                canWrite = state.canWrite,
                                busy = state.busyDeploymentId == dep.id,
                                onRetry = { viewModel.retry(dep) },
                                onRollback = { viewModel.rollback(dep) },
                            )
                        }
                    }
                }
            }
            SnackbarHost(snackbarHostState, Modifier.align(Alignment.BottomCenter).systemBarsPadding())
        }
    }

    if (showConfig) {
        ModalBottomSheet(onDismissRequest = { showConfig = false }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
            BuildConfigForm(
                config = state.project?.buildConfig,
                isSaving = state.busyDeploymentId == "config",
                onSave = { cmd, dest, root -> viewModel.updateBuildConfig(cmd, dest, root); showConfig = false },
            )
        }
    }

    if (showDeployChooser) {
        ModalBottomSheet(onDismissRequest = { showDeployChooser = false }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
            Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(stringResource(R.string.pages_deploy_code), fontSize = 18.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
                Text(stringResource(R.string.pages_deploy_hint), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 4.dp, bottom = 8.dp))
                DeployChoice(Icons.Outlined.InsertDriveFile, stringResource(R.string.pages_deploy_single)) { pendingZip = false; showDeployChooser = false; picker.launch("*/*") }
                DeployChoice(Icons.Outlined.Folder, stringResource(R.string.pages_deploy_zip)) { pendingZip = true; showDeployChooser = false; picker.launch("*/*") }
            }
        }
    }
}

@Composable
private fun DeployChoice(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, onClick: () -> Unit) {
    Surface(color = MaterialTheme.colorScheme.surfaceContainerLow, shape = RoundedCornerShape(12.dp), modifier = Modifier.fillMaxWidth().clickable(onClick = onClick)) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, contentDescription = null, tint = OcOrange, modifier = Modifier.width(22.dp))
            Spacer(Modifier.width(12.dp))
            Text(label, fontSize = 15.sp, color = MaterialTheme.colorScheme.onSurface)
        }
    }
}

@Composable
private fun BuildConfigForm(
    config: jiamin.chen.orangecloud.data.model.PagesBuildConfig?,
    isSaving: Boolean,
    onSave: (buildCommand: String, destinationDir: String, rootDir: String) -> Unit,
) {
    var cmd by rememberSaveable { mutableStateOf(config?.buildCommand.orEmpty()) }
    var dest by rememberSaveable { mutableStateOf(config?.destinationDir.orEmpty()) }
    var root by rememberSaveable { mutableStateOf(config?.rootDir.orEmpty()) }
    Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(stringResource(R.string.pages_edit_build), fontSize = 18.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
        OutlinedTextField(cmd, { cmd = it }, label = { Text(stringResource(R.string.pages_build_command)) }, singleLine = true, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(dest, { dest = it }, label = { Text(stringResource(R.string.pages_dest_dir)) }, singleLine = true, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(root, { root = it }, label = { Text(stringResource(R.string.pages_root_dir)) }, singleLine = true, modifier = Modifier.fillMaxWidth())
        Button(onClick = { onSave(cmd, dest, root) }, enabled = !isSaving, colors = ButtonDefaults.buttonColors(containerColor = OcOrange, contentColor = Color.White), modifier = Modifier.fillMaxWidth()) {
            if (isSaving) { CircularProgressIndicator(Modifier.height(18.dp).width(18.dp), strokeWidth = 2.dp, color = Color.White); Spacer(Modifier.width(8.dp)) }
            Text(stringResource(R.string.dns_save))
        }
    }
}

@Composable
private fun ProjectInfoCard(project: PagesProject) {
    Surface(color = MaterialTheme.colorScheme.surfaceContainerLow, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            project.subdomain?.let {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Outlined.Language, contentDescription = null, tint = OcOrange, modifier = Modifier.width(16.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(it, fontSize = 13.sp, fontFamily = FontFamily.Monospace, color = MaterialTheme.colorScheme.onSurface)
                }
            }
            project.productionBranch?.let {
                Text(stringResource(R.string.pages_prod_branch, it), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            project.source?.config?.repoLabel?.let {
                Text(it, fontSize = 13.sp, fontFamily = FontFamily.Monospace, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            project.buildConfig?.buildCommand?.takeIf { it.isNotBlank() }?.let {
                Text(stringResource(R.string.pages_build_cmd, it), fontSize = 12.sp, fontFamily = FontFamily.Monospace, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun DeploymentRow(
    dep: PagesDeployment,
    canWrite: Boolean,
    busy: Boolean,
    onRetry: () -> Unit,
    onRollback: () -> Unit,
) {
    Surface(color = MaterialTheme.colorScheme.surfaceContainerLow, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                StatusDot(deployStatusColor(dep.statusRaw), size = 8.dp)
                Spacer(Modifier.width(10.dp))
                Column(Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            stringResource(if (dep.isProduction) R.string.pages_production else R.string.pages_preview),
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = if (dep.isProduction) OcOrange else MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(stringResource(deployStatusLabel(dep.statusRaw)), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    val msg = dep.deploymentTrigger?.metadata?.commitMessage ?: dep.shortId ?: dep.id.take(8)
                    Text(msg, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                if (busy) CircularProgressIndicator(Modifier.width(20.dp), strokeWidth = 2.dp, color = OcOrange)
            }
            if (canWrite && !busy) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    TextButton(onClick = onRetry) {
                        Icon(Icons.Outlined.Refresh, contentDescription = null, tint = OcOrange, modifier = Modifier.width(16.dp))
                        Spacer(Modifier.width(4.dp))
                        Text(stringResource(R.string.pages_retry), color = OcOrange, fontSize = 13.sp)
                    }
                    if (!dep.isProduction || dep.statusRaw == "success") {
                        TextButton(onClick = onRollback) {
                            Icon(Icons.Outlined.Restore, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.width(16.dp))
                            Spacer(Modifier.width(4.dp))
                            Text(stringResource(R.string.pages_rollback), color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 13.sp)
                        }
                    }
                }
            }
        }
    }
}

private fun deployStatusLabel(status: String): Int = when (status) {
    "success" -> R.string.pages_status_success
    "idle" -> R.string.pages_status_idle
    "active" -> R.string.pages_status_active
    "failure" -> R.string.pages_status_failure
    "canceled" -> R.string.pages_status_canceled
    else -> R.string.pages_status_unknown
}

private fun deployStatusColor(status: String): Color = when (status) {
    "success" -> OcSuccess
    "failure" -> Color(0xFFE5484D)
    "active", "idle" -> Color(0xFFC77C00)
    else -> Color(0xFF8E8E93)
}
