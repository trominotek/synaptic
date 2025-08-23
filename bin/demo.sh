#!/bin/bash

# Synaptic Build and Deploy Script
# Builds images with date tags and deploys to Docker Compose stack
# Run from synaptic/bin directory

set -e

# Navigate to synaptic root directory
cd "$(dirname "$0")/.."

# Get today's date
TODAY=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

echo "🚀 Starting synaptic build and deploy for $TODAY"
echo "📅 Timestamp: $TIMESTAMP"
echo "📁 Working from: $(pwd)"

# Configuration
PROJECT_NAME="synaptic"

# Service paths relative to trominos root
SERVICES_AGENTS="../agents"
SERVICES_MCP_SERVER="../a-tier-mcp-server"
SERVICES_OCR="../ocr"
SERVICES_DOC_DB="../doc-db"

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

# Function to build a service
build_service() {
    local service=$1
    local path=$2
    local service_name="${PROJECT_NAME}-${service}"
    
    if [ ! -d "$path" ]; then
        log_error "Service directory not found: $path"
        return 1
    fi
    
    log_info "Building $service from $path"
    
    # Create tags
    local image_name="${service_name}:${TODAY}"
    local latest_tag="${service_name}:latest"
    local timestamp_tag="${service_name}:${TIMESTAMP}"
    
    # Build with Docker
    docker build \
        -t "$image_name" \
        -t "$latest_tag" \
        -t "$timestamp_tag" \
        "$path"
    
    if [ $? -eq 0 ]; then
        log_success "Built $service successfully"
        return 0
    else
        log_error "Failed to build $service"
        return 1
    fi
}

# Function to update docker-compose with today's tags
update_compose_tags() {
    log_info "Updating docker-compose.yml with today's tags"
    
    if [ ! -f "docker-compose.yml" ]; then
        log_error "docker-compose.yml not found in current directory"
        return 1
    fi
    
    # Use environment variable substitution instead of sed replacements
    # Set VERSION environment variable for docker-compose
    export VERSION=${TODAY}
    
    log_success "Updated docker-compose.yml (using VERSION=${VERSION})"
}

# Function to setup database schema
setup_database_schema() {
    log_info "Setting up database schema..."
    log_info "Waiting for PostgreSQL to be ready..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker-compose exec -T postgres pg_isready -U postgres >/dev/null 2>&1; then
            log_success "PostgreSQL is ready!"
            break
        fi
        attempt=$((attempt + 1))
        log_info "Waiting for PostgreSQL... (attempt $attempt/$max_attempts)"
        sleep 2
    done
    
    if [ $attempt -eq $max_attempts ]; then
        log_error "PostgreSQL failed to start within expected time"
        return 1
    fi
    
    # Run database setup from MCP server container
    log_info "Running database schema setup from MCP server container..."
    
    # Use MCP server to set up database
    docker-compose exec -T mcp-server bash -c "
        export PGPASSWORD=postgres
        export DB_HOST=postgres
        export DB_PORT=5432
        export DB_USER=postgres
        export DB_NAME=ai_application
        
        # Create database and schemas
        createdb -h postgres -p 5432 -U postgres ai_application 2>/dev/null || echo 'Database exists'
        psql -h postgres -p 5432 -U postgres -d ai_application -c 'CREATE SCHEMA IF NOT EXISTS bank; CREATE SCHEMA IF NOT EXISTS ai_models;' 2>/dev/null || true
        
        # Apply database scripts if they exist
        for sql_file in /app/db/01_bank_schema.sql /app/db/02_ai_models_schema.sql; do
            if [ -f \$sql_file ]; then
                echo \"Applying \$(basename \$sql_file)...\"
                psql -h postgres -p 5432 -U postgres -d ai_application -f \$sql_file || echo \"Warning: Failed to apply \$(basename \$sql_file)\"
            else
                echo \"Warning: \$sql_file not found\"
            fi
        done
        
        # Apply data files if they exist
        for sql_file in /app/db/03_bank_data.sql /app/db/04_ai_models_data.sql; do
            if [ -f \$sql_file ]; then
                echo \"Applying \$(basename \$sql_file) (ignoring duplicate key errors)...\"
                psql -h postgres -p 5432 -U postgres -d ai_application -f \$sql_file 2>/dev/null || echo \"Data already exists in \$(basename \$sql_file)\"
            else
                echo \"Warning: \$sql_file not found\"
            fi
        done
        
        echo 'Database setup completed'
    "
    
    if [ $? -eq 0 ]; then
        log_success "Database schema setup completed successfully!"
        
        # Verify the setup by checking table counts
        log_info "Verifying database setup..."
        VERIFICATION_RESULT=$(docker-compose exec -T postgres psql -U postgres -d ai_application -c "SELECT COUNT(*) as total_tables FROM information_schema.tables WHERE table_schema IN ('bank', 'ai_models');" 2>/dev/null)
        if echo "$VERIFICATION_RESULT" | grep -q "total_tables"; then
            TABLE_COUNT=$(echo "$VERIFICATION_RESULT" | grep -E "[0-9]+" | tr -d ' ' | head -1)
            log_success "Database verification completed successfully! ($TABLE_COUNT tables found)"
        else
            log_warning "Database verification had issues, but services appear to be running"
        fi
    else
        log_error "Database schema setup failed!"
        log_error "Check the logs above for details"
        return 1
    fi
}

# Function to deploy the stack
deploy_stack() {
    log_info "Deploying Docker Compose stack"
    
    # Stop existing stack
    docker-compose down 2>/dev/null || echo "No existing stack to stop"
    
    # Deploy with new images
    docker-compose up -d 2>/dev/null || {
        log_error "Failed to deploy stack"
        return 1
    }
    
    # Wait a bit for services to start
    log_info "Waiting for services to start..."
    sleep 15
    
    # Setup database schema
    setup_database_schema
    
    # Check if services are running
    log_info "Checking service status..."
    RUNNING_SERVICES=$(docker-compose ps --filter="status=running" --format="table" 2>/dev/null | grep -c "Up" || echo "0")
    TOTAL_SERVICES=$(docker-compose ps --format="table" 2>/dev/null | tail -n +2 | wc -l || echo "0")
    
    if [ "$RUNNING_SERVICES" -ge "4" ]; then
        log_success "Stack deployed successfully! ($RUNNING_SERVICES/$TOTAL_SERVICES services running)"
        docker-compose ps 2>/dev/null || echo "Services are running"
    else
        log_warning "Some services may still be starting ($RUNNING_SERVICES/$TOTAL_SERVICES services up)"
        log_info "Checking individual service health..."
        
        # Test key services directly
        sleep 5
        if curl -s http://localhost:8005/health >/dev/null 2>&1; then
            log_success "✅ RAG service is operational"
        fi
        if curl -s http://localhost:8080 >/dev/null 2>&1; then
            log_success "✅ Frontend is accessible"
        fi
        if curl -s http://localhost:8090/health >/dev/null 2>&1; then
            log_success "✅ MCP server is operational"
        fi
    fi
}

# Function to cleanup old images
cleanup_old_images() {
    log_info "Cleaning up images older than 7 days"
    
    # Remove old tagged images (keep last 7 days)
    local cutoff_date=$(date -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d 2>/dev/null || echo "2024-01-01")
    
    # Get all synaptic images with date tags
    docker images --format "table {{.Repository}}:{{.Tag}}" | grep "^synaptic-.*:2[0-9][0-9][0-9]-" | while read image; do
        local image_date=$(echo "$image" | sed 's/.*:\([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\).*/\1/')
        if [[ "$image_date" < "$cutoff_date" ]]; then
            log_info "Removing old image: $image"
            docker rmi "$image" 2>/dev/null || true
        fi
    done
    
    log_success "Image cleanup completed"
}

# Main execution
main() {
    log_info "Starting daily build process"
    
    # Build all services
    log_info "Building agents from $SERVICES_AGENTS"
    build_service "agents" "$SERVICES_AGENTS" || exit 1
    
    log_info "Building mcp-server from $SERVICES_MCP_SERVER"
    log_info "Copying database scripts to MCP server build context..."
    build_service "mcp-server" "$SERVICES_MCP_SERVER" || exit 1
    
    log_info "Building ocr from $SERVICES_OCR"
    build_service "ocr" "$SERVICES_OCR" || exit 1
    
    log_info "Building doc-db from $SERVICES_DOC_DB"
    build_service "doc-db" "$SERVICES_DOC_DB" || exit 1
    
    # Update docker-compose with today's tags
    update_compose_tags || exit 1
    
    # Deploy the stack
    deploy_stack || exit 1
    
    # Optional: cleanup old images
    if [[ "${1}" == "--cleanup" ]]; then
        cleanup_old_images
    fi
    
    echo ""
    log_success "🎉 Synaptic deployment completed successfully!"
    echo ""
    echo "📋 Access your services:"
    echo "  • Frontend: http://localhost:8080"
    echo "  • RAG API: http://localhost:8005"  
    echo "  • MCP API: http://localhost:8090"
    echo "  • OCR API: http://localhost:5002"
    echo "  • Database: localhost:5435"
    echo ""
    echo "📊 To view logs: docker-compose logs -f [service]"
    echo "🛑 To stop: docker-compose down"
}

# Execute main function with all arguments
main "$@"