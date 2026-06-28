package jiamin.chen.orangecloud.ui.workers

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import jiamin.chen.orangecloud.R
import jiamin.chen.orangecloud.core.design.SkyBackground
import jiamin.chen.orangecloud.core.design.SkyHeader
import jiamin.chen.orangecloud.core.design.onSky
import jiamin.chen.orangecloud.core.design.rememberSkyPhase
import jiamin.chen.orangecloud.core.design.theme.OcOrange

private const val SAMPLE_CODE =
    "export default {\n  async fetch(request, env, ctx) {\n    return new Response(\"Hello from Orange Cloud!\");\n  },\n};\n"

@Composable
fun WorkerCreateScreen(
    onBack: () -> Unit,
    onCreated: () -> Unit,
    viewModel: WorkerCreateViewModel = hiltViewModel(),
) {
    val isUploading by viewModel.isUploading.collectAsStateWithLifecycle()
    val phase = rememberSkyPhase()
    val onSky = phase.onSky
    val snackbar = remember { SnackbarHostState() }

    var name by rememberSaveable { mutableStateOf("") }
    var compatDate by rememberSaveable { mutableStateOf(viewModel.defaultCompatibilityDate) }
    var code by rememberSaveable { mutableStateOf(SAMPLE_CODE) }

    val createdMsg = stringResource(R.string.worker_create_ok)
    LaunchedEffect(Unit) {
        viewModel.events.collect { event ->
            when (event) {
                WorkerCreateEvent.Created -> { snackbar.showSnackbar(createdMsg); onCreated() }
                is WorkerCreateEvent.Error -> snackbar.showSnackbar(event.message ?: "")
            }
        }
    }

    val nameValid = name.isBlank() || viewModel.isValidName(name)
    val canSave = viewModel.isValidName(name) && code.isNotBlank() && !isUploading

    SkyBackground(phase = phase) {
        Column(Modifier.fillMaxSize().systemBarsPadding()) {
            SkyHeader(
                title = stringResource(R.string.worker_create_title),
                onSky = onSky,
                isLoading = isUploading,
                onRefresh = {},
                onBack = onBack,
                titleSize = 22,
                backDescription = stringResource(R.string.common_back),
            )
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it.lowercase() },
                    label = { Text(stringResource(R.string.worker_create_name)) },
                    singleLine = true,
                    isError = !nameValid,
                    supportingText = { Text(stringResource(R.string.worker_create_name_hint)) },
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = compatDate,
                    onValueChange = { compatDate = it },
                    label = { Text(stringResource(R.string.worker_create_compat)) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                Text(stringResource(R.string.worker_create_code), fontSize = 13.sp, color = onSky)
                OutlinedTextField(
                    value = code,
                    onValueChange = { code = it },
                    textStyle = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace),
                    minLines = 10,
                    modifier = Modifier.fillMaxWidth(),
                )
                Text(stringResource(R.string.worker_create_note), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Button(
                    onClick = { viewModel.create(name, code, compatDate) },
                    enabled = canSave,
                    colors = ButtonDefaults.buttonColors(containerColor = OcOrange, contentColor = Color.White),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    if (isUploading) {
                        CircularProgressIndicator(Modifier.height(18.dp).width(18.dp), strokeWidth = 2.dp, color = Color.White)
                        Spacer(Modifier.width(8.dp))
                    }
                    Text(stringResource(R.string.worker_create_deploy))
                }
            }
            SnackbarHost(snackbar)
        }
    }
}
