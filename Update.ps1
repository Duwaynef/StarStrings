# This script assumes that you have each Starcitizen path as a symbolic link to "LIVE" 
# so you only have one copy of the game and they all sit in live and you use the launcher to repair / update to each game branch

param(
    [switch]$IncludeUserCfg
)

# 1. Parse Configuration
$ConfigFile = Join-Path $PSScriptRoot "UpdateConf.csv"
if (-not (Test-Path $ConfigFile)) {
    Write-Error "UpdateConf.csv not found!"
    pause
    return
}

# Load the CSV file into an object
$Prefs = Import-Csv -Path $ConfigFile

# Look up the rows by their 'Name' and grab the corresponding 'Path'
$RepoURL          = ($Prefs | Where-Object Name -eq "RepoURL").Path
$BaseDir          = ($Prefs | Where-Object Name -eq "BaseDir").Path
$StarCitizenPath  = ($Prefs | Where-Object Name -eq "StarCitizenPath").Path

# Output the results to verify
Write-Host "URL:  $RepoURL" -ForegroundColor Green
Write-Host "Base: $BaseDir" -ForegroundColor Green
Write-Host "SC:   $StarCitizenPath" -ForegroundColor Green

# 2. Validate target folder
if (-not (Test-Path $StarCitizenPath)) {
    Write-Error "Target folder not found: $StarCitizenPath"
    pause
    return
}

# 3. Detect Available Branches (Folders)
Write-Host "`n[*] Scanning for available branches in $BaseDir..." -ForegroundColor Cyan
$AvailableFolders = Get-ChildItem -Path $BaseDir -Directory -Filter "StarStrings*"

if ($AvailableFolders.Count -eq 0) {
    Write-Error "No StarStrings folders found in $BaseDir. Run your sync script first!"
    pause
    return
}

# Build a menu array dynamically
$MenuOptions = @()
foreach ($Folder in $AvailableFolders) {
    # If it's the root folder it's master/main, otherwise strip the prefix to get the branch name
    $BranchName = if ($Folder.Name -eq "StarStrings") { "master" } else { $Folder.Name.Replace("StarStrings_", "") }
    
    $MenuOptions += [PSCustomObject]@{
        Branch = $BranchName
        Path   = $Folder.FullName
    }
}

# Display Menu
Write-Host "--------------------------------------------------" -ForegroundColor Gray
for ($i = 0; $i -lt $MenuOptions.Count; $i++) {
    Write-Host "[$($i + 1)] $($MenuOptions[$i].Branch)" -ForegroundColor White
}
Write-Host "--------------------------------------------------" -ForegroundColor Gray

# Get User Input
$Selection = 0
while ($Selection -lt 1 -or $Selection -gt $MenuOptions.Count) {
    [int]$Selection = Read-Host "Select the branch to use (1-$($MenuOptions.Count))"
}

$SelectedFolder = $MenuOptions[$Selection - 1].Path
$SelectedBranch = $MenuOptions[$Selection - 1].Branch

Write-Host "`n[*] Selected Branch: $SelectedBranch" -ForegroundColor Yellow

# 4. Git Update (using the clean output fix)
Write-Host "[INFO] Ensuring local branch files are up to date..." -ForegroundColor Cyan
Push-Location $SelectedFolder
try {
    git pull origin $SelectedBranch 2>&1 | ForEach-Object { "$_" } | Write-Host -ForegroundColor DarkGray
} catch {
    Write-Warning "[!] Could not perform git pull. Proceeding with existing local files."
}
Pop-Location

# 5. Sync Logic
Write-Host "`n[INFO] Syncing files to: $StarCitizenPath" -ForegroundColor Yellow

$IncludePatterns = [System.Collections.Generic.List[string]]@("global.ini", "user.cfg")
if (-not $IncludeUserCfg) {
    [void]$IncludePatterns.Remove("user.cfg")
    Write-Host "[!] Skipping user.cfg, use -IncludeUserCfg to include it" -ForegroundColor Gray
}

Get-ChildItem -Path $SelectedFolder -Recurse | Where-Object {
    $Name = $_.Name
    $IncludePatterns | Where-Object { $Name -like $_ }
} | ForEach-Object {
    # Calculate relative path based on the selected branch folder, not the script root
    $RelativePath = $_.FullName.Substring($SelectedFolder.Length).TrimStart('\')
    $DestinationPath = Join-Path $StarCitizenPath $RelativePath

    if ($_.PSIsContainer) {
        if (-not (Test-Path $DestinationPath)) {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        }
    } else {
        # Ensure the destination directory exists before copying
        $DestDir = Split-Path $DestinationPath -Parent
        if (-not (Test-Path $DestDir)) {
            New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
        }

        Copy-Item -Path $_.FullName -Destination $DestinationPath -Force
        Write-Host " Updated: $RelativePath" -ForegroundColor DarkGray
    }
}

Write-Host "`n[SUCCESS] Synchronization complete!" -ForegroundColor Green
pause