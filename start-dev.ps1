<#
PowerShell development startup script for StoatChat backend
- Ensures Docker is available and runs docker-compose up -d
- Starts backend binaries (delta, bonfire, autumn, january) in background jobs
- Provides simple health checks and useful logs
#>

param(
    [switch]$NoDockerCompose
)

Write-Host "Starting StoatChat development environment..." -ForegroundColor Cyan

# Helper to check command
function Command-Exists {
    param([string]$cmd)
    $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

# Check Docker availability
if (-not (Command-Exists docker)) {
    Write-Warning "Docker CLI not found. If you want to run services via docker-compose, install Docker Desktop or Docker Engine."
} else {
    try {
        docker version | Out-Null
    } catch {
        Write-Warning "Docker engine doesn't appear to be running or accessible. If on Windows, ensure Docker Desktop is started."
    }
}

# Run docker-compose up -d unless user opted out
if (-not $NoDockerCompose) {
    if (-not (Command-Exists docker-compose)) {
        Write-Warning "docker-compose command not found. Trying 'docker compose' as a fallback..."
        if (Command-Exists docker) {
            Write-Host "Running: docker compose up -d" -ForegroundColor Yellow
            docker compose up -d
        } else {
            Write-Warning "Neither docker-compose nor docker compose are available. Skipping container startup."
        }
    } else {
        Write-Host "Running: docker-compose up -d" -ForegroundColor Yellow
        docker-compose up -d
    }
}

# Function to start a cargo binary in a background job
function Start-RustService {
    param(
        [string]$binary, # name of the cargo binary (crate) e.g. revolt-delta
        [string]$workDir = "$(Get-Location)",
        [string]$label
    )

    # Fallback for label if not provided (PowerShell 5.1 doesn't support '??')
    if (-not $label -or $label -eq "") { $label = $binary }
    Write-Host "Starting $label ..." -ForegroundColor Green

    $script = {
        param($binaryParam, $workDirParam)
        try {
            if ($workDirParam -and (Test-Path $workDirParam)) {
                Set-Location $workDirParam
            }
        } catch {
            # ignore working directory change failures
        }

        # Run the cargo binary
        & cargo run --bin $binaryParam
    }

    # Pass both binary and workDir into the job so it runs in the right directory
    Start-Job -Name $label -ScriptBlock $script -ArgumentList $binary, $workDir | Out-Null
    Start-Sleep -Milliseconds 200
    Write-Host "$label started as job: $($label)" -ForegroundColor DarkCyan
}

# Optionally build once to speed multiple runs
Write-Host "Building Rust binaries (this may take a while)..." -ForegroundColor Yellow
# Use cargo build --bins to build all binaries once
try {
    & cargo build --bins
} catch {
    Write-Warning "cargo build failed or cargo is not available in PATH. You can run the binaries manually later."
}

# Start the services as jobs. Adjust crate names if different in this repo.
Start-RustService -binary "revolt-delta" -label "delta"
Start-RustService -binary "revolt-bonfire" -label "bonfire"
Start-RustService -binary "revolt-autumn" -label "autumn"
Start-RustService -binary "revolt-january" -label "january"

Write-Host "All requested services started as background jobs." -ForegroundColor Green
Write-Host "Use Get-Job to list jobs, Receive-Job -Id <id> to read output, Stop-Job -Id <id> to stop." -ForegroundColor Cyan
Write-Host "Docker containers can be inspected with: docker ps && docker logs <container>" -ForegroundColor Cyan

# Simple health check example: try pinging API root
Start-Sleep -Seconds 2
try {
    $resp = Invoke-WebRequest -Uri http://localhost:14702/ -UseBasicParsing -Method GET -TimeoutSec 2
    if ($resp.StatusCode -eq 200) {
        Write-Host "API responded at http://localhost:14702/" -ForegroundColor Green
    } else {
        Write-Host "API returned status $($resp.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Warning "Unable to reach API at http://localhost:14702/ (it may still be starting)"
}

Write-Host "Dev startup complete." -ForegroundColor Green
