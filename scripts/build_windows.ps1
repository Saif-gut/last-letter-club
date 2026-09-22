param([string]$Godot = 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$output = Join-Path $project 'builds/windows'
$logs = Join-Path $project '.godot/export-cache'
New-Item -ItemType Directory -Force -Path $output,$logs | Out-Null
$version = (& $Godot --version | Out-String).Trim()
if (-not $version.StartsWith('4.7.2.stable.')) { throw "Godot 4.7.2 required; found $version" }
& $Godot --headless --path $project --editor --import --quit *> (Join-Path $logs 'import.log')
if ($LASTEXITCODE -ne 0) { throw 'Import failed; see .godot/export-cache/import.log' }
& $Godot --headless --path $project --export-release 'Windows x86_64' (Join-Path $output 'LastLetterClub.exe') *> (Join-Path $logs 'export.log')
if ($LASTEXITCODE -ne 0) { Get-Content (Join-Path $logs 'export.log'); throw 'Windows export failed' }
$licenses = Join-Path $output 'licenses'
New-Item -ItemType Directory -Force -Path $licenses | Out-Null
& $Godot --headless --path $project --script res://tests/export_notices.gd -- (Join-Path $licenses 'Godot.txt') *> (Join-Path $logs 'licenses.log')
if ($LASTEXITCODE -ne 0) { throw 'License notice generation failed' }
Get-ChildItem (Join-Path $project 'resources/words') -Recurse -File | Where-Object { $_.Name -match 'LICENSE|COPYING' } | ForEach-Object {
    $relative = [System.IO.Path]::GetRelativePath((Join-Path $project 'resources/words'), $_.FullName).Replace('\','_')
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $licenses $relative)
}
@"
Last Letter Club - Windows x86_64 Testbuild
Engine: $version / Forward+
Start: LastLetterClub.exe (PCK und licenses im selben Ordner belassen).
WASD / Maus / Space; Esc gibt die Maus fuer Host/Join frei.
Alt+Enter wechselt Vollbild/Fenster. UDP-Port: 24572.
Kein Godot-Editor, Steam, Installer oder Account erforderlich.

Kurzer LAN-Test auf zwei PCs:
1. Gleicher Build, gleiches LAN/WLAN. Jeweils EXE starten.
2. Esc, auf PC A Host Lobby. LAN IP des Ethernet-/WLAN-Adapters ablesen.
3. PC B: Esc, diese IP unter Host Address eintragen, Join Lobby.
4. Beide laufen/springen, mit E am selben Tisch sitzen; Host startet mit F5.
5. Disconnect und erneutes Join pruefen.
Windows-Netzwerkzugriff fuer private Netzwerke muss erlaubt sein (UDP 24572).
Keine automatischen Firewall-/Routeraenderungen. LAN-Test ist kein Internet-Test.
"@ | Set-Content -Encoding utf8 (Join-Path $output 'START.txt')
Get-FileHash (Join-Path $output 'LastLetterClub.exe'),(Join-Path $output 'LastLetterClub.pck') -Algorithm SHA256 | Format-Table -AutoSize | Out-String | Set-Content (Join-Path $logs 'build-hashes.txt')
Write-Output "WINDOWS_BUILD: PASS - $output"
