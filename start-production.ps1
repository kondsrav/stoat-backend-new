# 🚀 Production Startup Script for Revolt Backend (PowerShell)
# This script sets up and runs the production environment on Windows

Write-Host "🔥 Starting Revolt Backend in Production Mode" -ForegroundColor Cyan
Write-Host "=============================================="

# Check if Docker is installed
try {
    docker --version | Out-Null
} catch {
    Write-Host "❌ Docker is not installed. Please install Docker Desktop first." -ForegroundColor Red
    exit 1
}

# Check if Docker Compose is available
try {
    docker-compose --version | Out-Null
} catch {
    Write-Host "❌ Docker Compose is not available. Please ensure Docker Desktop is running." -ForegroundColor Red
    exit 1
}

# Create data directories
Write-Host "📁 Creating data directories..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path "data"
New-Item -ItemType Directory -Force -Path "data\db"
New-Item -ItemType Directory -Force -Path "data\minio"
New-Item -ItemType Directory -Force -Path "data\rabbit"

# Check if override config exists
if (-not (Test-Path "Revolt.overrides.toml")) {
    Write-Host "❌ Revolt.overrides.toml not found. Please create it first." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Configuration files found" -ForegroundColor Green

# Build and start services
Write-Host "🏗️  Building and starting services..." -ForegroundColor Yellow
docker-compose -f compose.production.yml up --build -d

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to start services. Check Docker logs." -ForegroundColor Red
    exit 1
}

Write-Host "⏳ Waiting for services to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Check service health
Write-Host "🔍 Checking service health..." -ForegroundColor Yellow

Write-Host ""
Write-Host "🎉 Backend services are starting up!" -ForegroundColor Green
Write-Host ""
Write-Host "Services will be available at:" -ForegroundColor Cyan
Write-Host "  📊 API Server:    https://revolt-test.zasperhub.com/api" -ForegroundColor White
Write-Host "  🌐 WebSocket:     wss://revolt-test.zasperhub.com/ws" -ForegroundColor White
Write-Host "  📁 File Server:   https://revolt-test.zasperhub.com/autumn" -ForegroundColor White
Write-Host "  🔄 Proxy Server:  https://revolt-test.zasperhub.com/january" -ForegroundColor White
Write-Host ""
Write-Host "Management Interfaces:" -ForegroundColor Cyan
Write-Host "  📊 MinIO Console: http://localhost:14010" -ForegroundColor White
Write-Host "  🐰 RabbitMQ UI:   http://localhost:15672 (admin/admin)" -ForegroundColor White
Write-Host "  📧 MailDev UI:    http://localhost:14080" -ForegroundColor White
Write-Host ""
Write-Host "⚠️  IMPORTANT NEXT STEPS:" -ForegroundColor Yellow
Write-Host "   1. Configure your reverse proxy (Nginx/IIS) to handle HTTPS termination" -ForegroundColor White
Write-Host "   2. Update DNS to point revolt-test.zasperhub.com to this server" -ForegroundColor White
Write-Host "   3. Install SSL certificates for HTTPS" -ForegroundColor White
Write-Host "   4. Test frontend connection to the backend" -ForegroundColor White
Write-Host ""
Write-Host "Useful Commands:" -ForegroundColor Cyan
Write-Host "  View logs: docker-compose -f compose.production.yml logs -f" -ForegroundColor White
Write-Host "  Stop all:  docker-compose -f compose.production.yml down" -ForegroundColor White
Write-Host "  Restart:   docker-compose -f compose.production.yml restart" -ForegroundColor White