param(
    [Parameter(Mandatory=$true)]
    [string]$poolName
)

Import-Module WebAdministration -ErrorAction Stop

Write-Host ""
Write-Host "=========================================================="
Write-Host "Target Pool: $poolName"
Write-Host "=========================================================="

if (-not (Test-Path "IIS:\AppPools\$poolName")) {
    Write-Host "App Pool '$poolName' not found!" -ForegroundColor Red
    return
}

$pool = Get-Item "IIS:\AppPools\$poolName"

$currentStartMode = $pool.startMode
$startModeAction = "Already AlwaysRunning"
if ($currentStartMode -ne "AlwaysRunning") {
    Set-ItemProperty "IIS:\AppPools\$poolName" -Name startMode -Value "AlwaysRunning"
    $startModeAction = "Changed: $currentStartMode -> AlwaysRunning"
}

$allResults = @()
$foundAny = $false

Get-Website | ForEach-Object {
    $site = $_.Name

    $siteAppPool = (Get-ItemProperty "IIS:\Sites\$site" -Name applicationPool -ErrorAction SilentlyContinue).Value
    if ($siteAppPool -eq $poolName) {
        $foundAny = $true
        $currentPreload = (Get-ItemProperty "IIS:\Sites\$site" -Name preloadEnabled -ErrorAction SilentlyContinue).Value
        $preloadAction = "Already True"
        if ($currentPreload -ne $true) {
            Set-ItemProperty "IIS:\Sites\$site" -Name preloadEnabled -Value $true
            $preloadAction = "Changed: $currentPreload -> True"
        }
        $allResults += [PSCustomObject]@{
            Pool      = $poolName
            Path      = "$site (root)"
            StartMode = $startModeAction
            Preload   = $preloadAction
        }
    }

    Get-WebApplication -Site $site | ForEach-Object {
        $appPath = "$site$($_.Path)"
        if ($_.applicationPool -eq $poolName) {
            $foundAny = $true
            $currentPreload = (Get-ItemProperty "IIS:\Sites\$appPath" -Name preloadEnabled -ErrorAction SilentlyContinue).Value
            $preloadAction = "Already True"
            if ($currentPreload -ne $true) {
                Set-ItemProperty "IIS:\Sites\$appPath" -Name preloadEnabled -Value $true
                $preloadAction = "Changed: $currentPreload -> True"
            }
            $allResults += [PSCustomObject]@{
                Pool      = $poolName
                Path      = $appPath
                StartMode = $startModeAction
                Preload   = $preloadAction
            }
        }
    }
}

if (-not $foundAny) {
    $allResults += [PSCustomObject]@{
        Pool      = $poolName
        Path      = "(no site/app bound to this pool)"
        StartMode = $startModeAction
        Preload   = "N/A"
    }
}

Write-Host ""
Write-Host "=========================================================="
Write-Host "SUMMARY"
Write-Host "=========================================================="
$allResults | Format-Table -AutoSize