param([string]$TestScript = 'res://tests/network_lobby_test.gd', [string[]]$Scenarios = @('repeat','crash_host','crash_client'), [string[]]$ExtraArguments = @(), [string[]]$Roles = @('host','client'))
$ErrorActionPreference = 'Stop'
$enginePath = 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$logDirectory = Join-Path $projectPath ('.godot/network_checks/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
foreach ($scenario in $Scenarios) {
    $scenarioDirectory = Join-Path $logDirectory $scenario
    New-Item -ItemType Directory -Force -Path $scenarioDirectory | Out-Null
    $processes = @()
    try {
        foreach ($role in $Roles) {
            $arguments = @('--path', ('"' + $projectPath + '"'), '--windowed','--resolution','1280x720','--rendering-method','forward_plus','--script',$TestScript,'--', $role, ('"' + $scenarioDirectory + '"'), $scenario)
            $arguments += $ExtraArguments
            $processes += Start-Process -FilePath $enginePath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $scenarioDirectory ($role + '.log')) -RedirectStandardError (Join-Path $scenarioDirectory ($role + '.err'))
        }
        $deadline = (Get-Date).AddSeconds(90)
        while (@($processes | Where-Object { -not $_.HasExited }).Count -gt 0 -and (Get-Date) -lt $deadline) {
            Start-Sleep -Milliseconds 300
        }
        foreach ($index in 0..($Roles.Count - 1)) {
            $process = $processes[$index]
            $role = $Roles[$index]
            if (-not $process.HasExited) { throw "Network $role timed out. Logs: $logDirectory" }
            $output = (Get-Content -Raw (Join-Path $scenarioDirectory ($role + '.log'))) + (Get-Content -Raw (Join-Path $scenarioDirectory ($role + '.err')))
            if ($output -match '(SCRIPT ERROR|ERROR:|WARNING:)') {
                Write-Output $output
                throw "Network $scenario / $role reported an error. Logs: $scenarioDirectory"
            }
            if ($scenario -eq ('crash_' + $role)) {
                if (-not (Test-Path (Join-Path $scenarioDirectory 'crash_armed'))) { throw 'Crash test did not reach armed milestone' }
                Write-Output "$scenario / $role : deliberately terminated"
                continue
            }
            if (-not $output.Contains(('NETWORK_' + $role.ToUpper() + ': PASS'))) {
                Write-Output $output
                throw "Network $role failed. Logs: $logDirectory"
            }
            Write-Output "NETWORK_$($role.ToUpper()): PASS"
        }
		Write-Output "NETWORK_PROCESSES / ${scenario}: PASS · $scenarioDirectory"
    } finally {
        foreach ($process in $processes) {
            if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
        }
    }

}
