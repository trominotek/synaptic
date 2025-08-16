#!/bin/bash

# Master build script for all Synaptic services
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VERSION=${1:-"$(date +%Y%m%d-%H%M%S)"}
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

echo -e "${BLUE}🚀 Building all Synaptic services${NC}"
echo -e "${YELLOW}Version: ${VERSION}${NC}"
echo -e "${YELLOW}Build Date: ${BUILD_DATE}${NC}"
echo ""

# Function to build a service
build_service() {
    local service_name=$1
    local service_path=$2
    
    echo -e "${BLUE}📦 Building ${service_name}...${NC}"
    
    if [ -f "${service_path}/build.sh" ]; then
        cd "${service_path}"
        ./build.sh "${VERSION}"
        cd - > /dev/null
        echo -e "${GREEN}✅ ${service_name} built successfully${NC}"
    else
        echo -e "${RED}❌ Build script not found for ${service_name} at ${service_path}${NC}"
        exit 1
    fi
    echo ""
}

# Build all services
echo -e "${YELLOW}Building services in dependency order...${NC}"
echo ""

# Build OCR service (no dependencies)
build_service "OCR Service" "../ocr"

# Build A-Tier MCP Server (depends on database, but can be built independently)
build_service "A-Tier MCP Server" "../a-tier-mcp-server"

# Build Agents (depends on MCP server, but can be built independently)
build_service "Agents Frontend" "../agents"

echo -e "${GREEN}🎉 All services built successfully!${NC}"
echo ""
echo -e "${BLUE}Built images:${NC}"
docker images | grep "synaptic-" | head -6

echo ""
echo -e "${YELLOW}📋 Next steps:${NC}"
echo "1. Run 'docker-compose up -d' to start all services"
echo "2. Access the application at http://localhost"
echo "3. View logs with 'docker-compose logs -f [service]'"

# Create a version file for reference
echo "${VERSION}" > version.txt
echo -e "${GREEN}Version ${VERSION} saved to version.txt${NC}"