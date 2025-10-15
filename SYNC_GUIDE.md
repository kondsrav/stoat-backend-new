# 🚀 Revolt Backend & Frontend Synchronization Guide

This guide explains how to synchronize your Revolt backend with the frontend configuration to ensure seamless communication between the two.

## 📋 Overview

Your frontend is configured to connect to `revolt-test.zasperhub.com` while your backend was set up for local development only. This guide provides configurations for both local development and production deployment.

## 🔧 Quick Setup

### Option 1: Local Development (Recommended for testing)

1. **Start backend services:**
   ```bash
   cd d:\backend\stoatchat
   docker-compose up -d
   ```

2. **Start backend applications:**
   ```bash
   # Terminal 1 - API Server
   cargo run --bin revolt-delta

   # Terminal 2 - WebSocket Server  
   cargo run --bin revolt-bonfire

   # Terminal 3 - File Server
   cargo run --bin revolt-autumn

   # Terminal 4 - Proxy Server
   cargo run --bin revolt-january
   ```

3. **Start frontend:**
   ```bash
   cd d:\frontend\frontend
   pnpm dev:web
   ```

Your frontend will automatically detect it's running on localhost and connect to the local backend services.

### Option 2: Production Deployment

1. **Use production configuration:**
   ```bash
   cd d:\backend\stoatchat
   cp Revolt.overrides.toml Revolt.local.toml  # Backup existing config
   ```

2. **Start production stack:**
   ```powershell
   .\start-production.ps1
   ```

3. **Configure reverse proxy (Nginx):**
   - Copy `nginx.conf` to your web server
   - Update SSL certificate paths
   - Restart Nginx

## 📁 Configuration Files Created

### Backend Configurations

- **`Revolt.overrides.toml`** - Production configuration matching frontend URLs
- **`Revolt.development.toml`** - Local development configuration  
- **`compose.production.yml`** - Production Docker setup
- **`nginx.conf`** - Reverse proxy configuration for HTTPS

### Frontend Updates

- **Updated `env.ts`** - Now supports both local and production URLs automatically

## 🌐 URL Mapping

| Service | Local Development | Production |
|---------|------------------|------------|
| API | `http://localhost:14702` | `https://revolt-test.zasperhub.com/api` |
| WebSocket | `ws://localhost:14703` | `wss://revolt-test.zasperhub.com/ws` |
| File Server | `http://localhost:14704` | `https://revolt-test.zasperhub.com/autumn` |
| Proxy | `http://localhost:14705` | `https://revolt-test.zasperhub.com/january` |

## 🔨 Development Workflow

### Testing Locally

1. Start backend services:
   ```bash
   cd d:\backend\stoatchat
   docker-compose up -d redis database minio rabbit maildev
   ```

2. Run backend applications in development mode:
   ```bash
   # Each in a separate terminal
   cargo run --bin revolt-delta
   cargo run --bin revolt-bonfire  
   cargo run --bin revolt-autumn
   cargo run --bin revolt-january
   ```

3. Start frontend development server:
   ```bash
   cd d:\frontend\frontend
   pnpm dev:web
   ```

4. Visit `http://localhost:5173` - frontend will connect to local backend

### Building for Production

1. **Backend:**
   ```bash
   cd d:\backend\stoatchat
   docker-compose -f compose.production.yml up --build -d
   ```

2. **Frontend:**
   ```bash
   cd d:\frontend\frontend
   pnpm build:prod
   ```

## 🐛 Troubleshooting

### Common Issues

1. **CORS Errors:**
   - Ensure backend CORS configuration allows your frontend domain
   - Check that `AllowedOrigins::All` is set in delta/main.rs

2. **Connection Refused:**
   - Verify all backend services are running: `docker-compose ps`
   - Check firewall isn't blocking ports 14702-14705

3. **WebSocket Connection Failed:**
   - Ensure bonfire service is running on port 14703
   - Check WebSocket URL in browser developer tools

4. **File Upload Issues:**
   - Verify MinIO is running and accessible
   - Check autumn service logs: `docker-compose logs autumn`

### Service Health Checks

```bash
# Check API
curl http://localhost:14702/

# Check WebSocket (using wscat)
wscat -c ws://localhost:14703

# Check file service
curl http://localhost:14704/

# Check proxy service  
curl http://localhost:14705/
```

## 🔒 Production Security

For production deployment:

1. **SSL Certificates:**
   - Install valid SSL certificates for `revolt-test.zasperhub.com`
   - Update certificate paths in `nginx.conf`

2. **Database Security:**
   - Set strong MongoDB/Redis passwords
   - Restrict database access to localhost only

3. **Firewall Configuration:**
   - Only expose ports 80, 443 publicly
   - Keep backend ports (14702-14705) internal

4. **Environment Variables:**
   - Set production secrets in environment variables
   - Don't commit sensitive data to git

## 📝 Environment Variables

Create a `.env` file for production:

```env
# Database
MONGODB_URL=mongodb://localhost:27017
REDIS_URL=redis://localhost:6379

# SMTP
SMTP_HOST=your-smtp-server.com
SMTP_USERNAME=your-username
SMTP_PASSWORD=your-password

# S3/MinIO
S3_ENDPOINT=https://your-s3-endpoint
S3_ACCESS_KEY=your-access-key
S3_SECRET_KEY=your-secret-key

# Domain
EXTERNAL_DOMAIN=revolt-test.zasperhub.com
```

## 🚨 Important Notes

1. **DNS Configuration:** Ensure `revolt-test.zasperhub.com` points to your server
2. **SSL Required:** Production requires valid SSL certificates
3. **Port Forwarding:** If behind NAT, forward ports 80 and 443
4. **Backup Strategy:** Regularly backup MongoDB and uploaded files

## 📞 Support

If you encounter issues:

1. Check service logs: `docker-compose logs [service-name]`
2. Verify configuration files match your environment
3. Test each service individually
4. Check network connectivity between frontend and backend

The configuration is now synchronized between your frontend and backend! 🎉