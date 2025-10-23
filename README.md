# CRM Demo App

Modern CRM aplikacija izgrađena s Vue.js 3 (frontend) i Express.js (backend) koristeći PostgreSQL bazu podataka.

## 🚀 Značajke

- ✅ **Upravljanje klijentima** - Dodavanje, pregled, brisanje klijenata
- ✅ **Bilješke po klijentima** - Dodavanje i upravljanje bilješkama
- ✅ **Dashboard sa statistikom** - Pregled ukupnih klijenata i bilješki
- ✅ **JWT Autentikacija** - Sigurna prijava sustava
- ✅ **PostgreSQL Baza** - Relacijska baza podataka
- ✅ **Docker Container** - Lake pokretanje cijelog sustava

## 🛠 Tehnologije

- **Frontend**: Vue.js 3, Vite, Tailwind CSS, Axios
- **Backend**: Express.js, CORS, JWT
- **Baza podataka**: PostgreSQL
- **Containerizacija**: Docker, Docker Compose

## 📦 Brzo Pokretanje

### 🐳 Pokretanje preko Bash Skripti (Preporučeno)

```bash
# Pokreni aplikaciju
./start.sh

# Zaustavi aplikaciju  
./stop.sh

```

## 📦 Pokretanje  novog projekta sa demo podacima i db 

```bash
git clone git@github.com:DenisSeko/crm-demo-postgres.git
c/p setup.sh  ~/to/root/project/path
chmod +x setup.sh - premissions problemi(slučajno)
pokreni ./setup.sh 
cd crm-demo-postgres && ./start.sh

# 2. Pokreni aplikaciju
./start.sh

# 3. Zaustavi aplikaciju (kad završiš)
./stop.sh
```
