#!/bin/bash

# =============================================================================
# QUICK FIX - Najbrže rješenje za Upsun remote probleme
# =============================================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}⚡ UPSUN QUICK FIX${NC}\n"

# 1. Prikaži trenutne remote-ove
echo "1️⃣  Trenutni Git remote-ovi:"
git remote -v
echo ""

# 2. Pronađi ili kreiraj 'upsun' remote
HAS_UPSUN=false

if git remote get-url upsun &> /dev/null; then
    URL=$(git remote get-url upsun)
    if [[ "$URL" == *"platform.sh"* ]] || [[ "$URL" == *"upsun"* ]]; then
        echo -e "${GREEN}✅ Remote 'upsun' postoji i ispravan je!${NC}"
        echo "   $URL"
        HAS_UPSUN=true
    else
        echo -e "${YELLOW}⚠️  Remote 'upsun' postoji ali nije Upsun URL${NC}"
        echo "   Brišem ga..."
        git remote remove upsun
    fi
fi

# 3. Ako nema 'upsun', traži pod drugim imenom
if [ "$HAS_UPSUN" = false ]; then
    echo "2️⃣  Tražim Upsun remote..."
    
    for remote in $(git remote); do
        URL=$(git remote get-url "$remote")
        if [[ "$URL" == *"platform.sh"* ]] || [[ "$URL" == *"upsun"* ]]; then
            echo -e "${GREEN}   Pronađen pod imenom: '$remote'${NC}"
            echo "   Reimenujem u 'upsun'..."
            git remote rename "$remote" upsun
            HAS_UPSUN=true
            break
        fi
    done
fi

# 4. Ako i dalje nema, postavi ga
if [ "$HAS_UPSUN" = false ]; then
    echo "3️⃣  Postavljam Upsun remote..."
    
    # Pokušaj automatski sa project ID
    if upsun project:set-remote envpwlcf4e7e2 --yes 2>/dev/null; then
        echo -e "${GREEN}   Postavljen automatski!${NC}"
        
        # Pronađi i preimenuj
        for remote in $(git remote); do
            URL=$(git remote get-url "$remote")
            if [[ "$URL" == *"platform.sh"* ]] && [ "$remote" != "upsun" ]; then
                git remote rename "$remote" upsun 2>/dev/null
                break
            fi
        done
        HAS_UPSUN=true
    else
        echo -e "${YELLOW}   Ne mogu automatski postaviti remote${NC}"
    fi
fi

echo ""

# 5. Final status
if git remote get-url upsun &> /dev/null; then
    URL=$(git remote get-url upsun)
    echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ GOTOVO! Remote 'upsun' je postavljen!          ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "URL: $URL"
    echo ""
    echo "Deploy sa:"
    echo "  git push upsun staging"
    echo "  # ili"
    echo "  git push upsun main"
    echo ""
else
    echo -e "${YELLOW}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  ⚠️  Potrebna ručna intervencija                   ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Pokreni jednu od ovih opcija:"
    echo ""
    echo "Opcija 1 - Fix skripta (preporučeno):"
    echo "  ./fix-upsun-remote.sh"
    echo ""
    echo "Opcija 2 - Ručno:"
    echo "  upsun project:set-remote envpwlcf4e7e2"
    echo "  git remote rename [ime] upsun"
    echo ""
    echo "Opcija 3 - Deploy skripta:"
    echo "  ./deploy.sh"
fi