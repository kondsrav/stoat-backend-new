# Local Development Setup Guide

This guide shows you how to run both frontend and backend locally for development, then build updated Docker images for your self-hosted deployment.

## Prerequisites

- Docker Desktop (for dependencies)
- Node.js 18+ and pnpm (for frontend)
- Rust 1.70+ (for backend)
- Git

## 1. Frontend Setup (Already Configured)

The frontend has been configured to use localhost URLs automatically during development.

### Start Frontend Development Server

```powershell
# Navigate to frontend directory
cd D:\latest_frontend\for-web

# Install dependencies (if not already done)
pnpm install

# Start development server
pnpm dev:web
```

The frontend will be available at: http://localhost:5173/

## 2. Backend Setup

### Step 1: Start Backend Dependencies

```powershell
# Navigate to backend directory
cd D:\backend\stoatchat

# Start dependencies (MongoDB, Redis, RabbitMQ, MinIO)
docker compose -f compose.dev.yml up -d

# Verify services are running
docker compose -f compose.dev.yml ps
```

### Step 2: Start Backend Services

Option A - Use the PowerShell script (recommended):
```powershell
# This will build and start all backend services
.\start-dev.ps1
```

Option B - Manual startup:
```powershell
# Build all services first
cargo build --bins

# Start each service in separate terminals:
# Terminal 1: API Server
cargo run --bin revolt-delta

# Terminal 2: Events Service  
cargo run --bin revolt-bonfire

# Terminal 3: File Service
cargo run --bin revolt-autumn

# Terminal 4: Proxy Service
cargo run --bin revolt-january
```

### Step 3: Verify Backend is Running

```powershell
# Test API endpoint
curl http://localhost:14702/

# Should return JSON configuration
```

## 3. Development Workflow

Once both frontend and backend are running:

1. **Frontend**: http://localhost:5173/
2. **Backend API**: http://localhost:14702/
3. **MinIO Console**: http://localhost:14001/ (admin/password: minioautumn)
4. **MailHog (Email)**: http://localhost:14026/

### Making Changes

- **Frontend**: Changes auto-reload via Vite
- **Backend**: Restart the specific service you modified:
  ```powershell
  # Stop specific job
  Get-Job | Where-Object Name -eq "delta" | Stop-Job
  
  # Restart it
  cargo run --bin revolt-delta
  ```

## 4. Building for Production

### Build Frontend

```powershell
cd D:\latest_frontend\for-web

# Build for production
pnpm build

# The built files will be in packages/client/dist/
```

### Build Backend Docker Images

```powershell
cd D:\backend\stoatchat

# Build all services
docker build -t your-registry/stoat-api:latest -f Dockerfile .
docker build -t your-registry/stoat-bonfire:latest -f crates/bonfire/Dockerfile .
# Add other services as needed
```

## 5. Deploy to Self-Hosted Server

### Option A: Update Existing Deployment

1. Push your new images to a registry
2. Update your server's `compose.yml` to use new image tags
3. Pull and restart:

```bash
# On your server
cd ~/revolt
docker compose pull
docker compose up -d --force-recreate
```

### Option B: Build on Server

1. Copy your updated code to the server
2. Build locally on the server:

```bash
# On your server
cd ~/revolt
git pull  # or copy your updated files
docker compose build
docker compose up -d
```

## 6. Environment Configuration

### Development Environment Variables

Create `D:\latest_frontend\for-web\packages\client\.env.local`:
```env
VITE_API_URL=http://localhost:14702
VITE_WS_URL=ws://localhost:14703
VITE_MEDIA_URL=http://localhost:14704
VITE_PROXY_URL=http://localhost:14705
```

### Production Environment Variables

For your self-hosted server, ensure your `.env.web` has:
```env
VITE_API_URL=https://revolt-test.zasperhub.com/api
VITE_WS_URL=wss://revolt-test.zasperhub.com/ws
VITE_MEDIA_URL=https://revolt-test.zasperhub.com/autumn
VITE_PROXY_URL=https://revolt-test.zasperhub.com/january
```

## Troubleshooting

### Frontend Issues

- **404 errors**: Check backend services are running on correct ports
- **CORS errors**: Verify `cors_origins` in `Revolt.development.toml`
- **Build errors**: Run `pnpm install` and ensure all submodules are built

### Backend Issues

- **Connection refused**: Check Docker services with `docker compose -f compose.dev.yml ps`
- **Database errors**: Restart MongoDB: `docker compose -f compose.dev.yml restart database`
- **Port conflicts**: Ensure ports 14702-14705, 27017, 6379, 5672 are available

### Development Tips

1. **Logs**: Use `Get-Job | Receive-Job -Name "delta"` to see backend logs
2. **Database**: Connect to MongoDB at `mongodb://localhost:27017`
3. **Reset Data**: `docker compose -f compose.dev.yml down -v` removes all data
4. **Hot Reload**: Backend doesn't auto-reload, restart services after changes

---

This setup allows you to develop locally with full control, then deploy updated versions to your self-hosted server when ready.