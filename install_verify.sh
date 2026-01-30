#!/bin/bash

# Tybelos Circle - Script Installazione e Verifica Automatica
# Versione: 1.0
# Data: Gennaio 2026

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funzioni di utilità
print_header() {
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Funzione per verificare prerequisiti
check_prerequisites() {
    print_header "Verifica Prerequisiti"
    
    local missing_deps=()
    
    # Verifica Docker
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
        print_success "Docker installato (v$DOCKER_VERSION)"
    else
        print_error "Docker non trovato"
        missing_deps+=("docker")
    fi
    
    # Verifica Docker Compose
    if command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version | awk '{print $4}' | tr -d ',')
        print_success "Docker Compose installato (v$COMPOSE_VERSION)"
    else
        print_error "Docker Compose non trovato"
        missing_deps+=("docker-compose")
    fi
    
    # Verifica Git
    if command -v git &> /dev/null; then
        GIT_VERSION=$(git --version | awk '{print $3}')
        print_success "Git installato (v$GIT_VERSION)"
    else
        print_error "Git non trovato"
        missing_deps+=("git")
    fi
    
    # Verifica Node.js (opzionale per testing)
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        print_success "Node.js installato ($NODE_VERSION)"
    else
        print_warning "Node.js non trovato (opzionale, necessario per alcuni test)"
    fi
    
    # Verifica Python (opzionale per scripts)
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | awk '{print $2}')
        print_success "Python installato (v$PYTHON_VERSION)"
    else
        print_warning "Python non trovato (opzionale, necessario per script di verifica)"
    fi
    
    # Verifica curl
    if command -v curl &> /dev/null; then
        print_success "curl installato"
    else
        print_error "curl non trovato"
        missing_deps+=("curl")
    fi
    
    # Verifica jq (per parsing JSON)
    if command -v jq &> /dev/null; then
        print_success "jq installato"
    else
        print_warning "jq non trovato (opzionale, utile per testing API)"
    fi
    
    # Se mancano dipendenze critiche, interrompi
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Dipendenze mancanti: ${missing_deps[*]}"
        print_info "Installa le dipendenze mancanti e riprova."
        exit 1
    fi
    
    print_success "Tutti i prerequisiti critici sono soddisfatti\n"
}

# Funzione per setup iniziale
setup_environment() {
    print_header "Setup Ambiente"
    
    # Crea directory di progetto
    PROJECT_DIR="tybelos-circle"
    
    if [ -d "$PROJECT_DIR" ]; then
        print_warning "Directory $PROJECT_DIR già esistente"
        read -p "Vuoi rimuoverla e ricrearla? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$PROJECT_DIR"
            print_info "Directory rimossa"
        else
            cd "$PROJECT_DIR"
            print_info "Uso directory esistente"
            return
        fi
    fi
    
    # Crea struttura directory
    mkdir -p "$PROJECT_DIR"/{docs,config,scripts,tests}
    cd "$PROJECT_DIR"
    
    print_success "Directory di progetto creata: $PROJECT_DIR"
}

# Funzione per creare docker-compose.yml
create_docker_compose() {
    print_header "Creazione Docker Compose"
    
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:14
    container_name: tybelos-postgres
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-tybelos_circle}
      POSTGRES_USER: ${POSTGRES_USER:-tybelos}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-tybelos_dev_password}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U tybelos"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: tybelos-redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5

  api:
    image: tybelos/api:latest
    container_name: tybelos-api
    build:
      context: .
      dockerfile: Dockerfile.api
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=postgresql://tybelos:tybelos_dev_password@postgres:5432/tybelos_circle
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=${JWT_SECRET:-dev_jwt_secret_change_in_production}
      - ENVIRONMENT=development
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  voice:
    image: tybelos/voice:latest
    container_name: tybelos-voice
    build:
      context: .
      dockerfile: Dockerfile.voice
    ports:
      - "8081:8081"
    environment:
      - REDIS_URL=redis://redis:6379
      - OPENAI_API_KEY=${OPENAI_API_KEY:-}
      - ELEVENLABS_API_KEY=${ELEVENLABS_API_KEY:-}
    depends_on:
      - redis
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8081/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  postgres_data:
  redis_data:
EOF
    
    print_success "docker-compose.yml creato"
}

# Funzione per creare .env
create_env_file() {
    print_header "Configurazione Variabili d'Ambiente"
    
    if [ -f .env ]; then
        print_warning ".env già esistente"
        return
    fi
    
    cat > .env << EOF
# Database Configuration
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=tybelos_circle
POSTGRES_USER=tybelos
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379

# JWT Configuration
JWT_SECRET=$(openssl rand -base64 32)
JWT_EXPIRY=900

# API Keys (inserisci le tue chiavi)
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
ELEVENLABS_API_KEY=
PINECONE_API_KEY=

# App Configuration
ENVIRONMENT=development
API_VERSION=v1
LOG_LEVEL=debug

# Performance Targets (da PERFORMANCE_METRICS.md)
TARGET_RESPONSE_LATENCY_MS=2000
TARGET_ASR_ACCURACY_WER=0.05
TARGET_TTS_QUALITY_MOS=4.2
TARGET_UPTIME_PERCENT=99.9
TARGET_CONCURRENT_SESSIONS=10000
EOF
    
    print_success ".env creato con password generate"
    print_warning "IMPORTANTE: Modifica .env e inserisci le tue API keys!"
}

# Funzione per creare Dockerfiles di esempio
create_dockerfiles() {
    print_header "Creazione Dockerfiles"
    
    # Dockerfile per API
    cat > Dockerfile.api << 'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
EOF
    
    # Dockerfile per Voice
    cat > Dockerfile.voice << 'EOF'
FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements-voice.txt .
RUN pip install --no-cache-dir -r requirements-voice.txt

COPY . .

EXPOSE 8081

CMD ["python", "voice_server.py"]
EOF
    
    print_success "Dockerfiles creati"
}

# Funzione per avviare i servizi
start_services() {
    print_header "Avvio Servizi"
    
    print_info "Pulling immagini Docker..."
    docker-compose pull
    
    print_info "Building servizi..."
    docker-compose build
    
    print_info "Avvio container..."
    docker-compose up -d
    
    print_info "Attendo che i servizi siano pronti..."
    sleep 10
    
    # Verifica status
    docker-compose ps
    
    print_success "Servizi avviati"
}

# Funzione per verificare i servizi
verify_services() {
    print_header "Verifica Servizi"
    
    local all_healthy=true
    
    # Verifica PostgreSQL
    print_info "Verifica PostgreSQL..."
    if docker-compose exec -T postgres pg_isready -U tybelos &> /dev/null; then
        print_success "PostgreSQL: OK"
    else
        print_error "PostgreSQL: FAIL"
        all_healthy=false
    fi
    
    # Verifica Redis
    print_info "Verifica Redis..."
    if docker-compose exec -T redis redis-cli ping | grep -q "PONG"; then
        print_success "Redis: OK"
    else
        print_error "Redis: FAIL"
        all_healthy=false
    fi
    
    # Verifica API
    print_info "Verifica API..."
    if curl -f http://localhost:8080/health &> /dev/null; then
        print_success "API: OK"
        API_HEALTH=$(curl -s http://localhost:8080/health | jq -r '.status')
        print_info "  Status: $API_HEALTH"
    else
        print_error "API: FAIL"
        all_healthy=false
    fi
    
    # Verifica Voice
    print_info "Verifica Voice Service..."
    if curl -f http://localhost:8081/health &> /dev/null; then
        print_success "Voice Service: OK"
    else
        print_error "Voice Service: FAIL (potrebbero mancare API keys)"
        print_warning "  Aggiungi OPENAI_API_KEY e ELEVENLABS_API_KEY in .env"
        all_healthy=false
    fi
    
    if [ "$all_healthy" = true ]; then
        print_success "\nTutti i servizi sono operativi!"
    else
        print_error "\nAlcuni servizi hanno problemi. Controlla i log:"
        print_info "docker-compose logs [service_name]"
    fi
}

# Funzione per test API base
test_api_endpoints() {
    print_header "Test API Endpoints"
    
    # Test health check
    print_info "Test 1: Health Check"
    HEALTH_RESPONSE=$(curl -s http://localhost:8080/health)
    if echo "$HEALTH_RESPONSE" | jq -e '.status == "healthy"' &> /dev/null; then
        print_success "Health check: OK"
    else
        print_error "Health check: FAIL"
        echo "$HEALTH_RESPONSE" | jq '.'
    fi
    
    # Test registrazione (esempio)
    print_info "\nTest 2: User Registration"
    REG_RESPONSE=$(curl -s -X POST http://localhost:8080/v1/auth/register \
        -H "Content-Type: application/json" \
        -d '{
            "email": "test@example.com",
            "password": "TestPass123!",
            "name": "Test User"
        }')
    
    if echo "$REG_RESPONSE" | jq -e '.user_id' &> /dev/null; then
        print_success "Registrazione: OK"
    else
        print_warning "Registrazione: Potrebbe fallire se utente già esiste"
    fi
    
    # Test login
    print_info "\nTest 3: User Login"
    LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8080/v1/auth/login \
        -H "Content-Type: application/json" \
        -d '{
            "email": "test@example.com",
            "password": "TestPass123!"
        }')
    
    if TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.access_token' 2>/dev/null) && [ "$TOKEN" != "null" ]; then
        print_success "Login: OK"
        print_info "  Token: ${TOKEN:0:20}..."
        
        # Salva token per test successivi
        export TEST_TOKEN="$TOKEN"
        
        # Test autenticato
        print_info "\nTest 4: Get User Profile"
        PROFILE_RESPONSE=$(curl -s http://localhost:8080/v1/users/me \
            -H "Authorization: Bearer $TOKEN")
        
        if echo "$PROFILE_RESPONSE" | jq -e '.email' &> /dev/null; then
            print_success "Get Profile: OK"
            echo "$PROFILE_RESPONSE" | jq '{email, circle_id, created_at}'
        else
            print_error "Get Profile: FAIL"
        fi
    else
        print_error "Login: FAIL"
    fi
}

# Funzione per test performance
test_performance() {
    print_header "Test Performance (Target da PERFORMANCE_METRICS.md)"
    
    print_info "1. Response Latency (Target: <200ms P95)"
    
    TOTAL_TIME=0
    REQUESTS=10
    
    for i in $(seq 1 $REQUESTS); do
        START=$(date +%s%N)
        curl -s http://localhost:8080/health > /dev/null
        END=$(date +%s%N)
        DIFF=$((($END - $START) / 1000000))
        TOTAL_TIME=$(($TOTAL_TIME + $DIFF))
    done
    
    AVG_TIME=$(($TOTAL_TIME / $REQUESTS))
    
    if [ $AVG_TIME -lt 200 ]; then
        print_success "Average latency: ${AVG_TIME}ms (✓ sotto target di 200ms)"
    else
        print_warning "Average latency: ${AVG_TIME}ms (⚠ sopra target di 200ms)"
    fi
    
    print_info "\n2. Concurrent Requests"
    print_info "Invio 50 richieste concurrent..."
    
    START=$(date +%s)
    seq 1 50 | xargs -n1 -P50 -I{} curl -s http://localhost:8080/health > /dev/null
    END=$(date +%s)
    DURATION=$(($END - $START))
    
    print_success "50 richieste completate in ${DURATION}s"
    
    print_info "\n3. Database Query Performance"
    DB_QUERY_TIME=$(docker-compose exec -T postgres psql -U tybelos -d tybelos_circle -c "EXPLAIN ANALYZE SELECT 1;" 2>/dev/null | grep "Execution Time" | awk '{print $3}')
    
    if [ -n "$DB_QUERY_TIME" ]; then
        print_success "Database query time: ${DB_QUERY_TIME}ms"
    else
        print_warning "Non è stato possibile misurare il tempo di query"
    fi
}

# Funzione per mostrare comandi utili
show_useful_commands() {
    print_header "Comandi Utili"
    
    cat << 'EOF'
# Visualizza logs
docker-compose logs -f              # Tutti i servizi
docker-compose logs -f api          # Solo API
docker-compose logs -f voice        # Solo Voice

# Verifica status
docker-compose ps                   # Status container
docker stats                        # Risorse utilizzate

# Accesso a servizi
docker-compose exec api bash        # Shell in API container
docker-compose exec postgres psql -U tybelos -d tybelos_circle

# Restart servizi
docker-compose restart api
docker-compose restart voice

# Stop/Start
docker-compose stop
docker-compose start
docker-compose down                 # Stop e rimuovi container

# Test API
export TOKEN="your_token_here"
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/v1/users/me

# Backup database
docker-compose exec postgres pg_dump -U tybelos tybelos_circle > backup.sql

# Cleanup completo
docker-compose down -v
docker system prune -a
EOF
    
    print_info "\nDocs disponibili:"
    print_info "  - docs/ARCHITECTURE.md"
    print_info "  - docs/API.md"
    print_info "  - docs/PRD.md"
    print_info "  - docs/PERFORMANCE_METRICS.md"
}

# Funzione per generare report
generate_report() {
    print_header "Generazione Report"
    
    REPORT_FILE="installation_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$REPORT_FILE" << EOF
Tybelos Circle - Installation Report
=====================================
Data: $(date)
Hostname: $(hostname)
User: $(whoami)

VERSIONI SOFTWARE
-----------------
Docker: $(docker --version)
Docker Compose: $(docker-compose --version)
Git: $(git --version)
Node.js: $(node --version 2>/dev/null || echo "Non installato")
Python: $(python3 --version 2>/dev/null || echo "Non installato")

SERVIZI
-------
$(docker-compose ps)

HEALTH CHECKS
-------------
PostgreSQL: $(docker-compose exec -T postgres pg_isready -U tybelos 2>&1)
Redis: $(docker-compose exec -T redis redis-cli ping 2>&1)
API: $(curl -s http://localhost:8080/health | jq -r '.status' 2>&1)
Voice: $(curl -s http://localhost:8081/health | jq -r '.status' 2>&1)

CONFIGURAZIONE
--------------
Environment: $(grep ENVIRONMENT .env)
Database: $(grep POSTGRES_DB .env)
API Version: $(grep API_VERSION .env)

ENDPOINTS
---------
API: http://localhost:8080
Voice: http://localhost:8081
PostgreSQL: localhost:5432
Redis: localhost:6379

PROSSIMI PASSI
--------------
1. Aggiungi API keys in .env (OPENAI_API_KEY, ELEVENLABS_API_KEY, etc.)
2. Consulta INSTALLATION_GUIDE.md per test avanzati
3. Leggi API.md per documentazione completa endpoints
4. Verifica PERFORMANCE_METRICS.md per target di performance

EOF
    
    print_success "Report salvato in: $REPORT_FILE"
    
    # Mostra report
    cat "$REPORT_FILE"
}

# Menu principale
show_menu() {
    clear
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║              TYBELOS CIRCLE                                  ║
║              Installazione e Verifica                        ║
║              v1.0 - Gennaio 2026                            ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

EOF
    
    echo "Scegli un'opzione:"
    echo ""
    echo "  1) Installazione completa (consigliato per prima volta)"
    echo "  2) Verifica servizi esistenti"
    echo "  3) Test API endpoints"
    echo "  4) Test performance"
    echo "  5) Mostra comandi utili"
    echo "  6) Genera report"
    echo "  7) Visualizza logs"
    echo "  8) Stop servizi"
    echo "  9) Restart servizi"
    echo "  0) Esci"
    echo ""
    read -p "Scelta: " choice
    
    case $choice in
        1)
            check_prerequisites
            setup_environment
            create_docker_compose
            create_env_file
            create_dockerfiles
            start_services
            verify_services
            test_api_endpoints
            generate_report
            show_useful_commands
            ;;
        2)
            verify_services
            ;;
        3)
            test_api_endpoints
            ;;
        4)
            test_performance
            ;;
        5)
            show_useful_commands
            ;;
        6)
            generate_report
            ;;
        7)
            docker-compose logs -f
            ;;
        8)
            docker-compose stop
            print_success "Servizi arrestati"
            ;;
        9)
            docker-compose restart
            print_success "Servizi riavviati"
            ;;
        0)
            print_info "Arrivederci!"
            exit 0
            ;;
        *)
            print_error "Scelta non valida"
            sleep 2
            show_menu
            ;;
    esac
    
    echo ""
    read -p "Premi ENTER per continuare..."
    show_menu
}

# Main
main() {
    # Se script eseguito senza argomenti, mostra menu
    if [ $# -eq 0 ]; then
        show_menu
    else
        # Supporto per argomenti da linea di comando
        case $1 in
            install)
                check_prerequisites
                setup_environment
                create_docker_compose
                create_env_file
                create_dockerfiles
                start_services
                verify_services
                test_api_endpoints
                generate_report
                ;;
            verify)
                verify_services
                ;;
            test)
                test_api_endpoints
                test_performance
                ;;
            stop)
                docker-compose stop
                ;;
            start)
                docker-compose start
                ;;
            restart)
                docker-compose restart
                ;;
            logs)
                docker-compose logs -f
                ;;
            *)
                print_error "Comando sconosciuto: $1"
                echo "Uso: $0 [install|verify|test|stop|start|restart|logs]"
                exit 1
                ;;
        esac
    fi
}

# Esegui main
main "$@"
