#!/bin/bash

# Synaptic Docker Helper Script
# Manages Docker containers for production deployment
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
    echo "🐳 Synaptic Docker Helper"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  start         - Start all services with docker-compose"
    echo "  stop          - Stop all services"
    echo "  restart       - Restart all services"
    echo "  logs [svc]    - Show logs (optionally for specific service)"
    echo "  ps            - Show service status"
    echo "  build         - Build all Docker images"
    echo "  health        - Check service health"
    echo "  shell [svc]   - Open shell in service container"
    echo "  clean         - Clean up containers and volumes"
    echo "  help          - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 start                    # Start all services"
    echo "  $0 logs agents              # Show agents logs"
    echo "  $0 shell mcp-server         # Open shell in MCP server"
    echo "  $0 health                   # Check all service health"
}

# Function to start services
start_services() {
    log_info "Starting Synaptic services with Docker..."
    docker-compose up -d
    log_success "Services started. Use '$0 ps' to check status."
}

# Function to stop services
stop_services() {
    log_info "Stopping Synaptic services..."
    docker-compose down
    log_success "Services stopped."
}

# Function to restart services
restart_services() {
    log_info "Restarting Synaptic services..."
    docker-compose restart
    log_success "Services restarted."
}

# Function to show logs
show_logs() {
    local service=$1
    if [ -n "$service" ]; then
        log_info "Showing logs for $service..."
        docker-compose logs -f "$service"
    else
        log_info "Showing logs for all services..."
        docker-compose logs -f
    fi
}

# Function to show service status
show_status() {
    log_info "Service Status:"
    docker-compose ps
}

# Function to build images
build_images() {
    log_info "Building all Docker images..."
    ./bin/demo.sh
}

# Function to clean up
clean_up() {
    log_warning "This will remove all containers, volumes, and images. Continue? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log_info "Cleaning up Synaptic environment..."
        docker-compose down -v --rmi all
        docker system prune -f
        log_success "Cleanup completed."
    else
        log_info "Cleanup cancelled."
    fi
}

# Function to check service health
check_health() {
    log_info "Checking service health..."
    echo ""
    
    # Check each service
    if curl -s http://localhost:8080 >/dev/null 2>&1; then
        log_success "Frontend (8080): Healthy"
    else
        log_error "Frontend (8080): Not responding"
    fi
    
    if curl -s http://localhost:8005/health >/dev/null 2>&1; then
        log_success "Doc-DB RAG (8005): Healthy"
    else
        log_error "Doc-DB RAG (8005): Not responding"
    fi
    
    if curl -s http://localhost:8090/health >/dev/null 2>&1; then
        log_success "MCP Server (8090): Healthy"
    else
        log_error "MCP Server (8090): Not responding"
    fi
    
    if curl -s http://localhost:5002 >/dev/null 2>&1; then
        log_success "OCR Service (5002): Healthy"
    else
        log_error "OCR Service (5002): Not responding"
    fi
    
    # Check database
    if docker-compose exec -T postgres pg_isready -U postgres >/dev/null 2>&1; then
        log_success "PostgreSQL (5435): Healthy"
    else
        log_error "PostgreSQL (5435): Not responding"
    fi
}

# Function to open shell in service
open_shell() {
    local service=$1
    if [ -z "$service" ]; then
        log_error "Please specify a service: agents, mcp-server, ocr, doc-db, postgres"
        return 1
    fi
    
    log_info "Opening shell in $service..."
    docker-compose exec "$service" bash || docker-compose exec "$service" sh
}

# Main command handling
case "${1:-help}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    logs)
        show_logs "$2"
        ;;
    ps|status)
        show_status
        ;;
    build)
        build_images
        ;;
    clean)
        clean_up
        ;;
    health)
        check_health
        ;;
    shell)
        open_shell "$2"
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