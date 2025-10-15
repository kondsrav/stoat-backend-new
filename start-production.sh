#!/bin/bash

# 🚀 Production Startup Script for Revolt Backend
# This script sets up and runs the production environment

set -e

echo "🔥 Starting Revolt Backend in Production Mode"
echo "=============================================="

# Check if Docker and Docker Compose are installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create data directories
echo "📁 Creating data directories..."
mkdir -p data/db data/minio data/rabbit

# Set proper permissions
echo "🔒 Setting permissions..."
chmod 755 data
chmod -R 777 data/minio data/rabbit

# Check if override config exists
if [ ! -f "Revolt.overrides.toml" ]; then
    echo "❌ Revolt.overrides.toml not found. Please create it first."
    exit 1
fi

echo "✅ Configuration files found"

# Build and start services
echo "🏗️  Building and starting services..."
docker-compose -f compose.production.yml up --build -d

echo "⏳ Waiting for services to start..."
sleep 10

# Check service health
echo "🔍 Checking service health..."

# Check if MongoDB is running
if ! docker-compose -f compose.production.yml exec -T database mongosh --eval "db.adminCommand('ping')" &> /dev/null; then
    echo "⚠️  MongoDB is starting up..."
fi

# Check if Redis is running
if ! docker-compose -f compose.production.yml exec -T redis redis-cli ping &> /dev/null; then
    echo "⚠️  Redis is starting up..."
fi

echo ""
echo "🎉 Backend services are starting up!"
echo ""
echo "Services will be available at:"
echo "  📊 API Server:    https://revolt-test.zasperhub.com/api"
echo "  🌐 WebSocket:     wss://revolt-test.zasperhub.com/ws"
echo "  📁 File Server:   https://revolt-test.zasperhub.com/autumn"
echo "  🔄 Proxy Server:  https://revolt-test.zasperhub.com/january"
echo ""
echo "Management Interfaces:"
echo "  📊 MinIO Console: http://localhost:14010"
echo "  🐰 RabbitMQ UI:   http://localhost:15672"
echo "  📧 MailDev UI:    http://localhost:14080"
echo ""
echo "⚠️  IMPORTANT:"
echo "   1. Configure your reverse proxy (Nginx) to handle HTTPS termination"
echo "   2. Update DNS to point revolt-test.zasperhub.com to this server"
echo "   3. Install SSL certificates for HTTPS"
echo ""
echo "To view logs: docker-compose -f compose.production.yml logs -f"
echo "To stop:      docker-compose -f compose.production.yml down"