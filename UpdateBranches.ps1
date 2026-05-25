# --- CONFIGURATION ---

# 1. Parse Configuration
$ConfigFile = Join-Path $PSScriptRoot "UpdateConf.csv"

# Auto-generate the config file if it is missing
if (-not (Test-Path $ConfigFile)) {
    Write-Host "[!] UpdateConf.csv not found!" -ForegroundColor Yellow
    Write-Host "[*] Generating a new configuration file with default Star Citizen settings..." -ForegroundColor Cyan
    
    # Define the default CSV structure using standard RSI installation paths
    $DefaultConfig = @"
Name,Path
RepoURL,"https://github.com/Duwaynef/StarStrings"
BaseDir,"C:\Program Files\Roberts Space Industries\StarCitizen"
StarCitizenPath,"C:\Program Files\Roberts Space Industries\StarCitizen\LIVE"
"@
    
    # Save it to the file
    $DefaultConfig | Set-Content -Path $ConfigFile
    
    Write-Host "[+] Created UpdateConf.csv successfully." -ForegroundColor Green
    Write-Host "[!] Please open the file, verify your paths are correct for this PC, and run the script again." -ForegroundColor Yellow
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

# ---------------------

# Ensure the base directory exists
if (-not (Test-Path $BaseDir)) {
    New-Item -ItemType Directory -Path $BaseDir | Out-Null
}

Write-Host "[*] Fetching remote branch list from GitHub..." -ForegroundColor Cyan

# Get all remote branches using git ls-remote (cleans up the output to just get the names)
$Branches = git ls-remote --heads $RepoUrl | ForEach-Object {
    if ($_ -match 'refs/heads/(.*)') { $Matches[1] }
}

if (-not $Branches) {
    Write-Error "Could not retrieve branches. Ensure Git is installed and the repository URL is accessible."
    Exit
}

Write-Host "[+] Found branches: $($Branches -join ', ')" -ForegroundColor Green

# Loop through each branch
foreach ($Branch in $Branches) {
    Write-Host "`n--------------------------------------------------" -ForegroundColor Gray
    Write-Host "[*] Processing branch: $Branch" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------" -ForegroundColor Gray

    # Determine the folder name based on the branch name rules
    if ($Branch -eq "master" -or $Branch -eq "main") {
        $TargetFolder = Join-Path $BaseDir "StarStrings"
    } else {
        $TargetFolder = Join-Path $BaseDir "StarStrings_$Branch"
    }

    # Check if the folder already exists and is a git repository
    if (Test-Path (Join-Path $TargetFolder ".git")) {
        Write-Host "[*] Target folder exists. Updating..." -ForegroundColor Yellow
        
        # Save current location, jump into the folder
        Push-Location $TargetFolder
        
        try {
            # Strip the ErrorRecord metadata and force it into a pure string
            git fetch origin --prune 2>&1 | ForEach-Object { "$_" } | Write-Host -ForegroundColor DarkGray
            git checkout -f $Branch 2>&1 | ForEach-Object { "$_" } | Write-Host -ForegroundColor DarkGray
            git pull origin $Branch 2>&1 | ForEach-Object { "$_" } | Write-Host -ForegroundColor DarkGray
            
            Write-Host "[+] Successfully pulled latest changes for $Branch" -ForegroundColor Green
        }
        catch {
            Write-Warning "[!] Failed to update branch $Branch"
        }
        
        # Restore previous location
        Pop-Location
    } 
    else {
        # If the directory exists but isn't a git repo, clean it out first
        if (Test-Path $TargetFolder) {
            Remove-Item $TargetFolder -Recurse -Force
        }

        Write-Host "[*] Cloning branch '$Branch' into target folder..." -ForegroundColor Yellow
        
        # Clone only the specific branch directly into the target folder structure
        git clone --branch $Branch --single-branch $RepoUrl $TargetFolder
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[+] Successfully cloned $Branch to $TargetFolder" -ForegroundColor Green
        } else {
            Write-Warning "[!] Failed to clone branch $Branch"
        }
    }
}

Write-Host "`n[+] All branches processed successfully!" -ForegroundColor Green