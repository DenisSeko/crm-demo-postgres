#!/bin/bash

# =============================================================================
# Upsun Deployment Script za CRM Basic App
# =============================================================================

set -e  # Exit on error

# Boje za output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funkcije za pretty print
print_header() {
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  $1"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Funkcija za provjeru dependencies
check_dependencies() {
    print_header "Provjera dependencies..."
    
    if ! command -v git &> /dev/null; then
        print_error "Git nije instaliran!"
        exit 1
    fi
    print_success "Git je instaliran"
    
    if ! command -v node &> /dev/null; then
        print_warning "Node.js nije instaliran (potreban za lokalne testove)"
    else
        print_success "Node.js je instaliran ($(node --version))"
    fi
    
    if ! command -v upsun &> /dev/null; then
        print_error "Upsun CLI nije instaliran!"
        echo ""
        print_info "Instaliraj sa:"
        echo "curl -fsSL https://raw.githubusercontent.com/platformsh/cli/main/installer.sh | bash"
        exit 1
    fi
    print_success "Upsun CLI je instaliran ($(upsun --version))"
}

# Funkcija za provjeru Upsun login statusa
check_upsun_login() {
    print_header "Provjera Upsun login statusa..."
    
    if ! upsun auth:info &> /dev/null; then
        print_error "Nisi logiran u Upsun!"
        echo ""
        read -p "Želiš li se sada logirati? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            upsun login
            print_success "Uspješno logiran!"
        else
            print_error "Deployment otkazan - potreban je login"
            exit 1
        fi
    else
        print_success "Uspješno logiran u Upsun"
        upsun auth:info
    fi
}

# Funkcija za provjeru Git statusa
check_git_status() {
    print_header "Provjera Git statusa..."
    
    if [ -n "$(git status --porcelain)" ]; then
        print_warning "Imaš uncommited promjene!"
        git status --short
        echo ""
        read -p "Želiš li commitati sve promjene? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Commit poruka: " commit_msg
            git add .
            git commit -m "$commit_msg"
            print_success "Promjene commitane"
        else
            print_warning "Nastavljam sa deployment-om bez commit-a..."
        fi
    else
        print_success "Git status je čist"
    fi
}

# Funkcija za odabir/kreiranje projekta
setup_project() {
    print_header "Setup Upsun projekta..."
    
    # Provjeri postoji li remote
    if git remote get-url upsun &> /dev/null; then
        print_success "Upsun remote već postoji"
        PROJECT_URL=$(git remote get-url upsun)
        print_info "Remote URL: $PROJECT_URL"
        return
    fi
    
    echo ""
    echo "1) Poveži postojeći projekt"
    echo "2) Kreiraj novi projekt"
    read -p "Odaberi opciju (1/2): " -n 1 -r
    echo
    
    if [[ $REPLY == "1" ]]; then
        # Lista postojećih projekata
        print_info "Dohvaćam listu projekata..."
        upsun project:list
        echo ""
        read -p "Unesi Project ID: " project_id
        
        upsun project:set-remote "$project_id"
        print_success "Projekt povezan!"
        
    elif [[ $REPLY == "2" ]]; then
        read -p "Naziv projekta: " project_name
        read -p "Region (default: eu-5.platform.sh): " region
        region=${region:-eu-5.platform.sh}
        
        print_info "Kreiram novi projekt..."
        upsun project:create \
            --title "$project_name" \
            --region "$region" \
            --set-remote
        
        print_success "Projekt kreiran!"
    else
        print_error "Nevažeća opcija!"
        exit 1
    fi
}

# Funkcija za setup environment varijabli
setup_variables() {
    print_header "Setup environment varijabli..."
    
    # Provjeri postoji li JWT_SECRET
    if upsun variable:get JWT_SECRET &> /dev/null; then
        print_success "JWT_SECRET već postoji"
    else
        print_warning "JWT_SECRET nije postavljen!"
        read -p "Želiš li generirati random JWT_SECRET? (y/n): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            JWT_SECRET=$(openssl rand -base64 32)
            upsun variable:create \
                --level project \
                --name JWT_SECRET \
                --value "$JWT_SECRET" \
                --sensitive true \
                --visible-build false
            print_success "JWT_SECRET kreiran i postavljen"
        else
            read -p "Unesi JWT_SECRET: " jwt_input
            upsun variable:create \
                --level project \
                --name JWT_SECRET \
                --value "$jwt_input" \
                --sensitive true \
                --visible-build false
            print_success "JWT_SECRET postavljen"
        fi
    fi
    
    # Dodatne varijable
    echo ""
    read -p "Želiš li postaviti dodatne environment varijable? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        while true; do
            read -p "Naziv varijable (ili 'done' za nastavak): " var_name
            if [ "$var_name" == "done" ]; then
                break
            fi
            read -p "Vrijednost: " var_value
            read -p "Je li osjetljiva? (y/n): " -n 1 -r
            echo
            
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                upsun variable:create --name "$var_name" --value "$var_value" --sensitive true
            else
                upsun variable:create --name "$var_name" --value "$var_value"
            fi
            print_success "Varijabla $var_name postavljena"
        done
    fi
}

# Funkcija za lokalne testove (opcionalno)
run_local_tests() {
    print_header "Lokalni testovi..."
    
    read -p "Želiš li pokrenuti lokalne testove? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Preskačem testove"
        return
    fi
    
    # Backend testovi
    if [ -d "backend" ]; then
        print_info "Testiram backend..."
        cd backend
        if [ -f "package.json" ]; then
            if npm list --depth=0 &> /dev/null; then
                print_success "Backend dependencies OK"
            else
                print_warning "Instaliram backend dependencies..."
                npm install
            fi
            
            # Provjeri syntax
            if node -c server.js 2> /dev/null; then
                print_success "Backend syntax OK"
            else
                print_error "Backend syntax greška!"
                node -c server.js
                exit 1
            fi
        fi
        cd ..
    fi
    
    # Frontend testovi
    if [ -d "frontend" ]; then
        print_info "Testiram frontend..."
        cd frontend
        if [ -f "package.json" ]; then
            if npm list --depth=0 &> /dev/null; then
                print_success "Frontend dependencies OK"
            else
                print_warning "Instaliram frontend dependencies..."
                npm install
            fi
            
            # Test build
            print_info "Testiram frontend build..."
            if npm run build; then
                print_success "Frontend build OK"
            else
                print_error "Frontend build neuspješan!"
                exit 1
            fi
        fi
        cd ..
    fi
}

# Funkcija za deployment
deploy_to_upsun() {
    print_header "Deployment na Upsun..."
    
    # Odabir brancha
    CURRENT_BRANCH=$(git branch --show-current)
    print_info "Trenutni branch: $CURRENT_BRANCH"
    
    read -p "Deploy branch '$CURRENT_BRANCH' na Upsun? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        read -p "Unesi branch name: " deploy_branch
    else
        deploy_branch=$CURRENT_BRANCH
    fi
    
    # Push na Upsun
    print_info "Pushing na Upsun remote..."
    if git push upsun "$deploy_branch" --force-with-lease; then
        print_success "Kod uspješno pushed!"
    else
        print_error "Git push neuspješan!"
        exit 1
    fi
    
    # Prati deployment
    echo ""
    read -p "Želiš li pratiti deployment logove? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Praćenje deployment logova (CTRL+C za exit)..."
        upsun activity:log --type environment.push --tail
    fi
}

# Funkcija za post-deployment provjere
post_deployment_checks() {
    print_header "Post-deployment provjere..."
    
    sleep 5  # Pričekaj da se deployment završi
    
    # Dohvati URL
    APP_URL=$(upsun url --primary --pipe 2>/dev/null || echo "")
    
    if [ -n "$APP_URL" ]; then
        print_success "Aplikacija deployana na: $APP_URL"
        
        # Test health endpoint
        print_info "Testiram health endpoint..."
        if curl -f -s "${APP_URL}/api/health" > /dev/null 2>&1; then
            print_success "API je dostupan!"
        else
            print_warning "API možda još nije spreman (čekaj 1-2 minute)"
        fi
        
        echo ""
        read -p "Želiš li otvoriti aplikaciju u browseru? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            upsun url --primary
        fi
    else
        print_warning "Ne mogu dohvatiti URL aplikacije"
    fi
    
    # Provjeri database
    echo ""
    read -p "Želiš li provjeriti database inicijalizaciju? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Spajam se na database..."
        upsun ssh -A backend -- "node init-db.js"
    fi
}

# Funkcija za prikaz summary-a
show_summary() {
    print_header "Deployment Summary"
    
    echo -e "${GREEN}🎉 Deployment završen!${NC}\n"
    
    # Dohvati info
    APP_URL=$(upsun url --primary --pipe 2>/dev/null || echo "N/A")
    ENV_STATUS=$(upsun environment:info --property status 2>/dev/null || echo "N/A")
    
    echo "📋 Informacije:"
    echo "  • URL: $APP_URL"
    echo "  • Status: $ENV_STATUS"
    echo "  • Branch: $(git branch --show-current)"
    echo ""
    
    echo "🔐 Sigurnost:"
    echo "  • ODMAH promijeni admin lozinku!"
    echo "  • Default kredencijali: admin / admin123"
    echo ""
    
    echo "📚 Korisne komande:"
    echo "  • Logovi: upsun log --tail"
    echo "  • SSH: upsun ssh"
    echo "  • Database: upsun db:sql"
    echo "  • Variables: upsun variable:list"
    echo "  • Redeploy: upsun environment:redeploy"
    echo ""
    
    print_success "Sve gotovo! 🚀"
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

clear
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   █░█ █▀█ █▀ █░█ █▄░█   █▀▄ █▀▀ █▀█ █░░ █▀█ █▄█ █▀▀ █▀█     ║
║   █▄█ █▀▀ ▄█ █▄█ █░▀█   █▄▀ ██▄ █▀▀ █▄▄ █▄█ ░█░ ██▄ █▀▄     ║
║                                                               ║
║                    CRM Basic App                              ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_info "Starting deployment process..."
sleep 1

# Pokreni sve korake
check_dependencies
check_upsun_login
check_git_status
setup_project
setup_variables
run_local_tests
deploy_to_upsun
post_deployment_checks
show_summary

# Cleanup
print_info "Čišćenje temporary files..."
[ -d "frontend/dist" ] && rm -rf frontend/dist
[ -d "backend/node_modules" ] && print_info "Backend node_modules ostaju za dev"
[ -d "frontend/node_modules" ] && print_info "Frontend node_modules ostaju za dev"

print_success "Deployment script završen!"
exit 0