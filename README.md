# Synaptic

A multi-service application with AI capabilities, OCR processing, and database management.

## Services

- **PostgreSQL Database** (Port 5433): Banking database with customer, transaction, and fraud data
- **A-Tier MCP Server** (Port 8002): Python Flask API with RAG chatbot and prompt management
- **Agents Frontend** (Port 80): Angular application with Node.js backend
- **OCR Service** (Port 5001): Python Flask API for document text extraction

## Quick Start

### 1. Build Images
```bash
cd synaptic
./build-all.sh [version]
```

### 2. Configure Environment
```bash
cp .env.example .env
# Edit .env as needed
```

### 3. Start Services
```bash
docker-compose up -d
```

### 4. Access Application
- Frontend: http://localhost
- MCP Server API: http://localhost:8002
- OCR API: http://localhost:5001

## Build Scripts

### Individual Service Builds
```bash
# Build specific service
cd a-tier-mcp-server && ./build.sh [version]
cd agents && ./build.sh [version]
cd ocr && ./build.sh [version]
```

### Master Build
```bash
cd synaptic
./build-all.sh [version]
```

### Version Management
- If no version specified, timestamp version is used (YYYYMMDD-HHMMSS)
- Latest tag is always created alongside versioned tag
- Version is saved to `version.txt`

## Management Commands

```bash
# Start all services
docker-compose up -d

# Stop all services  
docker-compose down

# View logs
docker-compose logs -f [service]

# Rebuild and restart
./build-all.sh && docker-compose up -d --force-recreate

# View running containers
docker-compose ps
```

## Development

For development with live reload:
```bash
# Copy and modify environment
cp .env.example .env

# Start individual services in development mode
cd agents && npm run dev
cd a-tier-mcp-server && python flask_api.py
cd ocr && python ocr_api_app/run.py
```