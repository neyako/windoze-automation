# Static checks for config and data tables. Runs anywhere: pwsh ./tests/Test-Config.ps1 (exit code 1 on failure).

$root = Split-Path $PSScriptRoot
$failures = @()
function Assert($ok, $msg) { if (-not $ok) { $script:failures += $msg } }

# Every script parses.
foreach ($f in Get-ChildItem $root -Recurse -Filter *.ps1 | Where-Object FullName -notmatch '[\\/]games[\\/]') {
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errors)
    Assert (-not $errors) "$($f.Name) does not parse: $($errors | Select-Object -First 1)"
}

# Tweak rows stay rows (PowerShell flattens @(@(...) @(...)) without leading commas).
. "$root\lib\debloat.ps1"
foreach ($t in $Tweaks) {
    Assert ($t.Count -eq 3 -and $t[0] -like 'HK*:\*' -and $t[1] -is [string] -and $t[2] -is [int]) "bad tweak row: $($t -join ' | ')"
}

$config = Import-PowerShellDataFile "$root\config.psd1"
$ids = $config.Runtimes + $config.Apps
Assert ($ids.Count -eq ($ids | Sort-Object -Unique).Count) 'duplicate winget IDs'
Assert (-not ($config.RemoveAppx | Where-Object { $_ -in '*', '*Microsoft*', 'Microsoft.WindowsStore', 'Microsoft.DesktopAppInstaller' })) 'RemoveAppx would remove Store/winget'
Assert ($config.StartupKeep.Count -gt 0) 'StartupKeep is empty'

if ($failures) { $failures | ForEach-Object { Write-Host "FAIL $_" -ForegroundColor Red }; exit 1 }
Write-Host "ok: $($Tweaks.Count) tweaks, $($ids.Count) packages, $($config.RemoveAppx.Count) removals"
