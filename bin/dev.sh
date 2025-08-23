#!/bin/bash

# Synaptic Development Script
# Runs services in development mode outside containers
# Run from synaptic/bin directory

set -e

# Navigate to synaptic root directory
cd "$(dirname "$0")/.."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

show_help() {
    echo "🚀 Synaptic Development Helper"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  start         - Start all services in development mode"
    echo "  stop          - Stop all development services"
    echo "  status        - Show running development processes"
    echo "  frontend      - Start only frontend (agents) in dev mode"
    echo "  mcp-server    - Start only MCP server in dev mode"
    echo "  ocr           - Start only OCR service in dev mode"
    echo "  doc-db        - Start only doc-db RAG service in dev mode"
    echo "  postgres      - Start only PostgreSQL (via Docker)"
    echo "  install       - Install dependencies for all services"
    echo "  clean         - Clean up development processes"
    echo "  help          - Show this help"
    echo ""
    echo "Development Features:"
    echo "  • Hot reload for frontend changes"
    echo "  • Direct file editing without rebuilds"
    echo "  • Faster startup times"
    echo "  • Live log output"
    echo ""
    echo "Examples:"
    echo "  $0 start                    # Start all services in dev mode"
    echo "  $0 frontend                 # Start only frontend"
    echo "  $0 status                   # Check running processes"
}

# Function to check if a port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Function to start PostgreSQL via Docker (needed for other services)
start_postgres() {
    log_info "Starting PostgreSQL database (via Docker)..."
    
    if check_port 5435; then
        log_success "PostgreSQL already running on port 5435"
        return 0
    fi
    
    # Start just postgres from docker-compose
    docker-compose up -d postgres
    
    # Wait for postgres to be ready
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker-compose exec -T postgres pg_isready -U postgres >/dev/null 2>&1; then
            log_success "PostgreSQL is ready!"
            return 0
        fi
        attempt=$((attempt + 1))
        log_info "Waiting for PostgreSQL... (attempt $attempt/$max_attempts)"
        sleep 2
    done
    
    log_error "PostgreSQL failed to start"
    return 1
}

# Function to install dependencies
install_dependencies() {
    log_info "Installing dependencies for all services..."
    
    # Frontend dependencies
    if [ -d "../agents" ]; then
        log_info "Installing frontend dependencies..."
        cd ../agents && npm install
        cd - > /dev/null
        log_success "Frontend dependencies installed"
    fi
    
    # MCP Server dependencies
    if [ -d "../a-tier-mcp-server" ]; then
        log_info "Installing MCP server dependencies..."
        cd ../a-tier-mcp-server
        if [ ! -d "venv" ]; then
            python3 -m venv venv
        fi
        source venv/bin/activate
        pip install -r requirements.txt
        deactivate
        cd - > /dev/null
        log_success "MCP server dependencies installed"
    fi
    
    # OCR Service dependencies
    if [ -d "../ocr" ]; then
        log_info "Installing OCR service dependencies..."
        cd ../ocr
        if [ ! -d "venv" ]; then
            python3 -m venv venv
        fi
        source venv/bin/activate
        pip install -r ocr_api_app/requirements.txt
        deactivate
        cd - > /dev/null
        log_success "OCR service dependencies installed"
    fi
    
    # Doc-DB dependencies
    if [ -d "../doc-db" ]; then
        log_info "Installing Doc-DB dependencies..."
        cd ../doc-db
        if [ ! -d "venv" ]; then
            python3 -m venv venv
        fi
        source venv/bin/activate
        pip install -r requirements.txt
        deactivate
        cd - > /dev/null
        log_success "Doc-DB dependencies installed"
    fi
    
    log_success "All dependencies installed!"
}

# Function to start frontend in development mode
start_frontend() {
    log_info "Starting frontend (agents) in development mode..."
    
    if check_port 4200; then
        log_warning "Port 4200 already in use"
        return 1
    fi
    
    if [ ! -d "../agents" ]; then
        log_error "Agents directory not found"
        return 1
    fi
    
    cd ../agents
    
    # Check if dependencies are installed
    if [ ! -d "node_modules" ]; then
        log_info "Installing dependencies first..."
        npm install
    fi
    
    # Start Angular dev server in background
    log_info "Starting Angular dev server on http://localhost:4200"
    nohup npm run start > ../synaptic/logs/frontend.log 2>&1 &
    echo $! > ../synaptic/logs/frontend.pid
    
    cd - > /dev/null
    log_success "Frontend started in development mode"
}

# Function to start MCP server in development mode
start_mcp_server() {
    log_info "Starting MCP server in development mode..."
    
    if check_port 8000; then
        log_warning "Port 8000 already in use"
        return 1
    fi
    
    if [ ! -d "../a-tier-mcp-server" ]; then
        log_error "MCP server directory not found"
        return 1
    fi
    
    cd ../a-tier-mcp-server
    
    # Activate virtual environment
    if [ ! -d "venv" ]; then
        log_info "Creating virtual environment..."
        python3 -m venv venv
        source venv/bin/activate
        pip install -r requirements.txt
    else
        source venv/bin/activate
    fi
    
    # Set environment variables
    export FLASK_ENV=development
    export FLASK_DEBUG=1
    export DB_HOST=localhost
    export DB_PORT=5435
    export DB_NAME=ai_application
    export DB_USER=postgres
    export DB_PASSWORD=postgres
    
    # Start Flask server in background
    log_info "Starting MCP server on http://localhost:8000"
    nohup python flask_api.py > ../synaptic/logs/mcp-server.log 2>&1 &
    echo $! > ../synaptic/logs/mcp-server.pid
    
    deactivate
    cd - > /dev/null
    log_success "MCP server started in development mode"
}

# Function to start OCR service in development mode
start_ocr() {
    log_info "Starting OCR service in development mode..."
    
    if check_port 5000; then
        log_warning "Port 5000 already in use"
        return 1
    fi
    
    if [ ! -d "../ocr" ]; then
        log_error "OCR directory not found"
        return 1
    fi
    
    cd ../ocr
    
    # Activate virtual environment
    if [ ! -d "venv" ]; then
        log_info "Creating virtual environment..."
        python3 -m venv venv
        source venv/bin/activate
        pip install -r ocr_api_app/requirements.txt
    else
        source venv/bin/activate
    fi
    
    # Set environment variables
    export FLASK_ENV=development
    export FLASK_DEBUG=1
    
    # Start Flask server in background
    log_info "Starting OCR service on http://localhost:5000"
    nohup python ocr_api_app/run.py > ../synaptic/logs/ocr.log 2>&1 &
    echo $! > ../synaptic/logs/ocr.pid
    
    deactivate
    cd - > /dev/null
    log_success "OCR service started in development mode"
}

# Function to start doc-db service in development mode
start_doc_db() {
    log_info "Starting Doc-DB RAG service in development mode..."
    
    if check_port 8005; then
        log_warning "Port 8005 already in use"
        return 1
    fi
    
    if [ ! -d "../doc-db" ]; then
        log_error "Doc-DB directory not found"
        return 1
    fi
    
    cd ../doc-db
    
    # Activate virtual environment
    if [ ! -d "venv" ]; then
        log_info "Creating virtual environment..."
        python3 -m venv venv
        source venv/bin/activate
        pip install -r requirements.txt
    else
        source venv/bin/activate
    fi
    
    # Set environment variables
    export FLASK_ENV=development
    export FLASK_DEBUG=1
    export CHROMADB_PATH=/Users/tojojose/trominos/doc-db
    export CORS_ORIGINS=http://localhost:4200,http://localhost:8080
    
    # Start Flask server in background
    log_info "Starting Doc-DB RAG service on http://localhost:8005"
    nohup python advanced_rag_service.py > ../synaptic/logs/doc-db.log 2>&1 &
    echo $! > ../synaptic/logs/doc-db.pid
    
    deactivate
    cd - > /dev/null
    log_success "Doc-DB RAG service started in development mode"
}

# Function to start all services
start_all() {
    log_info "Starting all services in development mode..."
    
    # Create logs directory
    mkdir -p logs
    
    # Start PostgreSQL first (required by other services)
    start_postgres || exit 1
    
    # Wait a moment for postgres to be fully ready
    sleep 3
    
    # Start all other services
    start_ocr || log_warning "OCR service failed to start"
    start_mcp_server || log_warning "MCP server failed to start"
    start_doc_db || log_warning "Doc-DB service failed to start"
    start_frontend || log_warning "Frontend failed to start"
    
    echo ""
    log_success "Development environment started!"
    echo ""
    echo "🌐 Service URLs:"
    echo "  • Frontend (dev): http://localhost:4200"
    echo "  • MCP Server: http://localhost:8000"
    echo "  • OCR Service: http://localhost:5000"
    echo "  • Doc-DB RAG: http://localhost:8005"
    echo "  • PostgreSQL: localhost:5435"
    echo ""
    echo "📊 View logs: tail -f logs/[service].log"
    echo "🛑 Stop all: $0 stop"
}

# Function to stop all services
stop_all() {
    log_info "Stopping all development services..."
    
    # Stop background processes
    for service in frontend mcp-server ocr doc-db; do
        if [ -f "logs/${service}.pid" ]; then
            local pid=$(cat "logs/${service}.pid")
            if kill -0 "$pid" 2>/dev/null; then
                log_info "Stopping $service (PID: $pid)"
                kill "$pid" 2>/dev/null || true
                rm -f "logs/${service}.pid"
            fi
        fi
    done
    
    # Stop PostgreSQL container
    docker-compose down postgres 2>/dev/null || true
    
    log_success "All development services stopped"
}

# Function to show status
show_status() {
    log_info "Development Services Status:"
    echo ""
    
    # Check each service
    local services_running=0
    
    if [ -f "logs/frontend.pid" ] && kill -0 "$(cat logs/frontend.pid)" 2>/dev/null; then
        log_success "Frontend (4200): Running (PID: $(cat logs/frontend.pid))"
        services_running=$((services_running + 1))
    else
        log_error "Frontend (4200): Not running"
    fi
    
    if [ -f "logs/mcp-server.pid" ] && kill -0 "$(cat logs/mcp-server.pid)" 2>/dev/null; then
        log_success "MCP Server (8000): Running (PID: $(cat logs/mcp-server.pid))"
        services_running=$((services_running + 1))
    else
        log_error "MCP Server (8000): Not running"
    fi
    
    if [ -f "logs/ocr.pid" ] && kill -0 "$(cat logs/ocr.pid)" 2>/dev/null; then
        log_success "OCR Service (5000): Running (PID: $(cat logs/ocr.pid))"
        services_running=$((services_running + 1))
    else
        log_error "OCR Service (5000): Not running"
    fi
    
    if [ -f "logs/doc-db.pid" ] && kill -0 "$(cat logs/doc-db.pid)" 2>/dev/null; then
        log_success "Doc-DB RAG (8005): Running (PID: $(cat logs/doc-db.pid))"
        services_running=$((services_running + 1))
    else
        log_error "Doc-DB RAG (8005): Not running"
    fi
    
    # Check PostgreSQL
    if check_port 5435; then
        log_success "PostgreSQL (5435): Running"
        services_running=$((services_running + 1))
    else
        log_error "PostgreSQL (5435): Not running"
    fi
    
    echo ""
    log_info "Total: $services_running/5 services running"
}

# Function to clean up
clean_up() {
    log_warning "This will stop all services and clean up development files. Continue? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        stop_all
        rm -rf logs/
        log_success "Development environment cleaned up"
    else
        log_info "Cleanup cancelled"
    fi
}

# Main command handling
case "${1:-help}" in
    start)
        start_all
        ;;
    stop)
        stop_all
        ;;
    status)
        show_status
        ;;
    frontend)
        mkdir -p logs && start_frontend
        ;;
    mcp-server)
        mkdir -p logs && start_postgres && sleep 3 && start_mcp_server
        ;;
    ocr)
        mkdir -p logs && start_ocr
        ;;
    doc-db)
        mkdir -p logs && start_postgres && sleep 3 && start_doc_db
        ;;
    postgres)
        start_postgres
        ;;
    install)
        install_dependencies
        ;;
    clean)
        clean_up
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac