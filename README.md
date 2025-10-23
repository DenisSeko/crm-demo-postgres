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

crm-demo-postgres/
├── frontend/ # Vue.js 3 frontend aplikacija
│ ├── src/
│ │ ├── components/ # Vue komponente
│ │ ├── App.vue # Glavna komponenta
│ │ └── main.js # Vue inicijalizacija
│ ├── package.json
│ └── vite.config.js
├── backend/ # Express.js backend server
│ ├── server.js # Glavni server file
│ ├── database/
│ │ └── config.js # PostgreSQL konfiguracija
│ └── package.json
├── database/ # SQL skripte i inicijalni podaci
├── docker-compose.yml # Docker konfiguracija
├── start.sh # Skripta za pokretanje
├── stop.sh # Skripta za zaustavljanje
└── README.md

### Koraci za inicijalizaciju projekta "from the scratch".

mkdir CRMVueApp && ./setup.sh

cd crm-demo-postgres && ./start.sh




