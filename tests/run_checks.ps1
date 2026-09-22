param([string]$Phase = 'current')
$ErrorActionPreference = 'Stop'
$enginePath = 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$logDirectory = Join-Path $projectPath ('.godot/checks-' + $Phase)
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$checks = @(
    @{Name='import'; Args=@('--headless','--editor','--import','--quit'); Marker=$null},
    @{Name='round_rules_test'; Headless=$true; Marker='ROUND_RULES: PASS'},
    @{Name='mature_words_test'; Headless=$true; Marker='MATURE_WORDS: PASS'},
    @{Name='prefix_rules_test'; Headless=$true; Marker='PREFIX_RULES: PASS'}
)
if (Test-Path (Join-Path $PSScriptRoot 'difficulty_test.gd')) {
    $checks += @{Name='difficulty_test'; Headless=$true; Marker='DIFFICULTY: PASS'}
}
if (Test-Path (Join-Path $PSScriptRoot 'network_edge_test.gd')) {
    $checks += @{Name='network_edge_test'; Headless=$true; Marker='NETWORK_EDGE: PASS'}
}
if (Test-Path (Join-Path $PSScriptRoot 'online_round_rules_test.gd')) {
    $checks += @{Name='online_round_rules_test'; Headless=$true; Marker='ONLINE_ROUND_RULES: PASS'}
    $checks += @{Name='online_disconnect_test'; Headless=$true; Marker='ONLINE_DISCONNECT: PASS'}
}
$checks += @(
    @{Name='host_address_test'; Headless=$true; Marker='HOST_ADDRESS: PASS'},
    @{Name='network_panel_test'; Headless=$true; Marker='NETWORK_PANEL: PASS'},
    @{Name='player_registry_test'; Headless=$true; Marker='PLAYER_REGISTRY: PASS'},
    @{Name='prototype_smoke'; Marker='PROTOTYPE_SMOKE: PASS'},
    @{Name='lobby_smoke'; Marker='LOBBY_SMOKE: PASS'},
    @{Name='countdown_flow'; Marker='COUNTDOWN_FLOW: PASS'}
)
foreach ($check in $checks) {
    $engineArgs = @('--path', $projectPath)
    if ($check.Name -eq 'import') { $engineArgs += $check.Args }
    else {
        if ($check.Headless) { $engineArgs += '--headless' }
        else { $engineArgs += @('--rendering-method','forward_plus') }
        $engineArgs += @('--script', ('res://tests/' + $check.Name + '.gd'))
        if (-not $check.Headless) { $engineArgs += @('--','--capture') }
    }
    $output = & $enginePath @engineArgs 2>&1 | Out-String
    $result = $LASTEXITCODE
    $output | Set-Content -Encoding utf8 (Join-Path $logDirectory ($check.Name + '.log'))
    if ($result -ne 0 -or $output -match '(?m)(SCRIPT ERROR|ERROR:|WARNING:)' -or ($check.Marker -and -not $output.Contains($check.Marker))) {
        Write-Output $output
        throw "Check failed: $($check.Name)"
    }
    Write-Output "$($check.Name): PASS"
}
Write-Output "PHASE $Phase : PASS"
