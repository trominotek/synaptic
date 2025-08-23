# Synaptic

A comprehensive multi-service AI application with RAG capabilities, OCR processing, and database management.

## Services

- **Agents Frontend** (Port 8080): Angular application with Node.js backend and RAG Chatbot UI
- **Doc-DB RAG Service** (Port 8005): Advanced RAG system with ChromaDB and 399 aviation handbook chunks
- **MCP Server** (Port 8090): Python Flask API with prompt management and API key handling  
- **OCR Service** (Port 5002): Python Flask API for document text extraction
- **PostgreSQL Database** (Port 5435): Banking database with customer, transaction, and fraud data

## Quick Start

### 1. Full Build and Deploy (Recommended)
```bash
cd synaptic
bin/demo.sh
```

### 2. Development Mode (Recommended for Development)
```bash
# Install dependencies first
bin/dev.sh install

# Start all services in development mode (outside containers)
bin/dev.sh start

# Check development service status
bin/dev.sh status

# Start individual services
bin/dev.sh frontend    # Angular dev server on :4200
bin/dev.sh mcp-server  # MCP server on :8000
bin/dev.sh doc-db      # RAG service on :8005

# Stop development services
bin/dev.sh stop
```

### 3. Docker Mode (For Production Testing)
```bash
# Start all services with docker-compose
bin/docker.sh start

# Check service health
bin/docker.sh health

# View logs
bin/docker.sh logs [service]

# Stop services
bin/docker.sh stop
```

### 4. Access Application

#### Development Mode URLs:
- **Frontend (dev)**: http://localhost:4200 (with hot reload)
- **MCP Server**: http://localhost:8000
- **OCR Service**: http://localhost:5000
- **RAG API**: http://localhost:8005
- **Database**: localhost:5435

#### Production Mode URLs:
- **Frontend**: http://localhost:8080
- **MCP Server**: http://localhost:8090
- **OCR Service**: http://localhost:5002
- **RAG API**: http://localhost:8005
- **Database**: localhost:5435

## Available Scripts

### Deployment Scripts (`bin/` directory)

#### `bin/demo.sh` - Full Build and Deploy
- Builds all service images with date tags
- Updates docker-compose.yml with new tags  
- Deploys complete stack with database setup
- Verifies service health

```bash
bin/demo.sh                 # Full build and deploy
bin/demo.sh --cleanup       # Build, deploy, and cleanup old images
```

#### `bin/dev.sh` - Development Mode Helper  
Runs services in development mode outside containers:

```bash
bin/dev.sh install          # Install dependencies for all services
bin/dev.sh start            # Start all services in dev mode
bin/dev.sh stop             # Stop all dev services  
bin/dev.sh status           # Show running processes
bin/dev.sh frontend         # Start only frontend (Angular dev server)
bin/dev.sh mcp-server       # Start only MCP server
bin/dev.sh doc-db           # Start only RAG service
bin/dev.sh ocr              # Start only OCR service
bin/dev.sh clean            # Clean up development processes
```

#### `bin/docker.sh` - Docker Production Helper  
Manages Docker containers for production testing:

```bash
bin/docker.sh start         # Start all services with docker-compose
bin/docker.sh stop          # Stop all services
bin/docker.sh restart       # Restart services
bin/docker.sh logs [svc]    # Show logs
bin/docker.sh ps            # Show service status
bin/docker.sh health        # Check service health
bin/docker.sh shell [svc]   # Open shell in container
bin/docker.sh clean         # Clean up containers and volumes
```

## Features

### 🤖 RAG Chatbot System
- **Airplane Flying AI Chat**: Advanced RAG system with 399 aviation handbook chunks
- **ChromaDB Integration**: Vector database with persistent storage
- **Claude AI Integration**: Powered by Anthropic's Claude for intelligent responses
- **Dual Chat Interfaces**: Synaptic AI Chat + Airplane Flying AI Chat

### 🔧 Development Features  
- **Hot Reload**: Development mode with live updates
- **Health Monitoring**: Built-in health checks for all services
- **Container Management**: Easy start/stop/restart commands
- **Log Aggregation**: Centralized logging across all services

### 🛠 Architecture
- **Microservices**: Containerized services with Docker Compose
- **Database**: PostgreSQL with comprehensive banking schema
- **API Gateway**: MCP server for centralized API management  
- **Document Processing**: OCR service for document text extraction
- **Frontend**: Modern Angular application with responsive design

## Environment Setup

### Prerequisites
- Docker and Docker Compose
- curl (for health checks)
- 8GB+ RAM recommended for all services

### Environment Variables
```bash
# Required
ANTHROPIC_API_KEY=your_anthropic_api_key_here

# Optional (defaults provided)
VERSION=2025-08-22
```