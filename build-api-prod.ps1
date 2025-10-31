#!/usr/bin/env pwsh
# Production build script for Stoat Chat Backend API
# Run this from the stoatchat directory

Write-Host "🚀 Building Stoat Chat Backend API Production Image..." -ForegroundColor Green

# Build API service with production URLs
Write-Host "📦 Building API service with production configuration..." -ForegroundColor Yellow
docker build -f Dockerfile.api.prod -t stoat-api-production:latest .

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ API service built successfully!" -ForegroundColor Green
    Write-Host "🔧 You can now run: docker-compose -f compose.prod.yml up -d" -ForegroundColor Cyan
    Write-Host "📊 Check logs: docker-compose -f compose.prod.yml logs -f api" -ForegroundColor Yellow
} else {
    Write-Host "❌ API build failed!" -ForegroundColor Red
}
