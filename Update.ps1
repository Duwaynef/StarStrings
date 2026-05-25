param(
    [switch]$IncludeUserCfg
)

# 1. Parse Configuration
$ConfigFile = Join-Path $PSScriptRoot "UpdateConf.txt"
if (-not (Test-Path $ConfigFile)) {
    Write-Error "UpdateConf.txt not found!"
    pause
    return
}

$ConfigContent = Get-Content $ConfigFile | Out-String
if ($ConfigContent -match 'StarCitizenPath\s*=\s*"(.*)"') {
    $TargetFolder = $Matches[1]
} else {
    Write-Error "Could not parse StarCitizenPath in UpdateConf.txt. Ensure format is: StarCitizenPath=`"C:\path\to\LIVE`""
    pause
    return
}

# 2. Validate target folder
if (-not (Test-Path $TargetFolder)) {
    Write-Error "Target folder not found: $TargetFolder"
    pause
    return
}

# 3. Git Update
Write-Host "[INFO] Updating repository via Git..." -ForegroundColor Cyan
git pull
if ($LASTEXITCODE -ne 0) {
    Write-Error "Git pull failed (exit code $LASTEXITCODE)!"
    pause
    return
}

# 4. Sync Logic
Write-Host "[INFO] Syncing files to: $TargetFolder" -ForegroundColor Yellow

$IncludePatterns = [System.Collections.Generic.List[string]]@("global.ini", "user.cfg")
if (-not $IncludeUserCfg) {
    [void]$IncludePatterns.Remove("user.cfg")
    Write-Host "[!] Skipping user.cfg, use -IncludeUserCfg to include it" -ForegroundColor Gray
}

Get-ChildItem -Path $PSScriptRoot -Recurse  | Where-Object {
    $Name = $_.Name
    $_.Name -like ($IncludePatterns | Where-Object { $Name -like $_ })
} | ForEach-Object {
    $RelativePath = $_.FullName.Substring($PSScriptRoot.Length).TrimStart('\')
    $DestinationPath = Join-Path $TargetFolder $RelativePath

    if ($_.PSIsContainer) {
        if (-not (Test-Path $DestinationPath)) {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        }
    } else {
        Copy-Item -Path $_.FullName -Destination $DestinationPath -Force
        Write-Host " Updated: $RelativePath" -ForegroundColor DarkGray
    }
}

Write-Host "`n[SUCCESS] Synchronization complete!" -ForegroundColor Green
pause