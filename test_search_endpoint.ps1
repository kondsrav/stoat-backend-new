#!/usr/bin/env pwsh

Write-Host "Testing custom search API endpoint..." -ForegroundColor Green

# Test 1: Without authentication (should get 401)
Write-Host "`n1. Testing without auth (should fail):" -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:14702/users/search?query=pa&limit=10" -Method GET
    Write-Host "Unexpected success: $($response.StatusCode)" -ForegroundColor Red
} catch {
    Write-Host "Expected 401 Unauthorized: $($_.Exception.Response.StatusCode)" -ForegroundColor Green
}

# Test 2: Check if endpoint exists (OPTIONS request)
Write-Host "`n2. Testing if endpoint exists:" -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:14702/users/search" -Method OPTIONS
    Write-Host "Endpoint exists! Status: $($response.StatusCode)" -ForegroundColor Green
} catch {
    if ($_.Exception.Response.StatusCode -eq 405) {
        Write-Host "Endpoint exists but OPTIONS not allowed (this is normal)" -ForegroundColor Green
    } else {
        Write-Host "Error: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    }
}

# Test 3: Check basic API health
Write-Host "`n3. Testing basic API health:" -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:14702/" -Method GET
    Write-Host "API is running! Status: $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "API not responding: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTo test with authentication, you'll need to:" -ForegroundColor Cyan
Write-Host "1. Open browser to http://localhost:5174" -ForegroundColor White
Write-Host "2. Log in to your account" -ForegroundColor White
Write-Host "3. Try the search functionality in 'Add member to group'" -ForegroundColor White