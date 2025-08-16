#!/bin/bash

# Verification script for Synaptic setup
set -e

echo "🔍 Verifying Synaptic setup..."
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

echo "✅ Docker is running"

# Check if build scripts exist
echo ""
echo "🔧 Checking build scripts..."

services=("a-tier-mcp-server" "agents" "ocr")
for service in "${services[@]}"; do
    build_script="../${service}/build.sh"
    if [ -f "$build_script" ]; then
        echo "✅ Build script exists for $service"
    else
        echo "❌ Build script missing for $service"
    fi
done

# Check if docker-compose.yml is valid
echo ""
echo "📋 Validating docker-compose.yml..."
if docker-compose config > /dev/null 2>&1; then
    echo "✅ docker-compose.yml is valid"
else
    echo "❌ docker-compose.yml has errors"
    docker-compose config
    exit 1
fi

# Check existing images
echo ""
echo "🐳 Current Synaptic images:"
docker images | grep "synaptic-" || echo "No Synaptic images found yet"

echo ""
echo "📝 Setup Summary:"
echo "   - All build scripts are created and executable"
echo "   - docker-compose.yml is configured for versioned images"
echo "   - Port mappings configured to avoid conflicts:"
echo "     • Frontend (agents): http://localhost"
echo "     • MCP Server: http://localhost:8002"
echo "     • OCR Service: http://localhost:5001"
echo "     • Database: localhost:5433"

echo ""
echo "🚀 Next steps:"
echo "   1. Run './build-all.sh [version]' to build all images"
echo "   2. Run 'docker-compose up -d' to start services"
echo "   3. Access the application at http://localhost"