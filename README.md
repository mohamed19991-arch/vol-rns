# VOL-RNS — Gestion des vols hebdomadaires

Application Android de gestion des vols aériens hebdomadaires avec notifications push.

- **Mobile** : Flutter + Dart (`mobile/`)
- **Backend** : Python + Django REST Framework (`backend/`)
- **Base de données** : PostgreSQL hébergé (Neon)
- **Notifications** : Firebase Cloud Messaging (FCM)
- **Auth** : JWT (djangorestframework-simplejwt)
- **Documentation API** : Swagger / OpenAPI (drf-spectacular)
- **Fuseau horaire** : `Africa/Algiers` — heures 24 h — dates `JJ/MM/AAAA` — interface en français

```
VOL_RNS/
├── backend/     Django + API REST + tests
├── mobile/      Application Flutter (Android)
├── docs/        Architecture, configuration, déploiement
├── .env.example
└── .gitignore
```

## 1. Prérequis

| Outil | Version conseillée |
| --- | --- |
| Python | 3.11+ |
| Flutter SDK | 3.19+ |
| Compte Neon (PostgreSQL) | offre gratuite |
| Projet Firebase | pour les notifications push |
| Compte hébergeur (Render/Railway/Fly.io…) | offre gratuite |

## 2. Démarrage rapide du backend

```bash
cd backend

# Environnement virtuel
python -m venv .venv
# Windows
.venv\Scripts\activate
# Linux / macOS
source .venv/bin/activate

# Dépendances
pip install -r requirements.txt

# Configuration
copy .env.example .env      # Windows
# cp .env.example .env      # Linux / macOS
# puis renseigner DATABASE_URL (Neon) et DJANGO_SECRET_KEY

# Base de données
python manage.py migrate

# Données initiales (destinations + administrateur)
python manage.py seed_initial_data --admin-email admin@vol-rns.local --admin-password "MotDePasse!123"

# Lancement
python manage.py runserver
```

- API : `http://127.0.0.1:8000/api/`
- Swagger : `http://127.0.0.1:8000/api/docs/`
- Admin Django : `http://127.0.0.1:8000/admin/`

> En développement, si `DATABASE_URL` est absent, un repli **SQLite** local est utilisé.
> En production, PostgreSQL (Neon) est **obligatoire** — voir `docs/DEPLOYMENT.md`.

## 3. Démarrage rapide du mobile

```bash
cd mobile
flutter pub get

# Émulateur Android : 10.0.2.2 = localhost de la machine hôte
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api

# Appareil physique (adresse IP de la machine) :
# flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000/api
```

Placez `android/app/google-services.json` (projet Firebase) pour activer les notifications push.
Sans ce fichier, l'application démarre sans notifications.

## 4. Tests

```bash
cd backend
python manage.py test          # 82 tests automatisés
```

## 5. Génération de l'APK / AAB

```bash
cd mobile
flutter build apk --release
flutter build appbundle --release
```

## 6. Rôles

| Rôle | Droits principaux |
| --- | --- |
| `admin` | Utilisateurs, rôles, destinations, programmes, vols, annonces, notifications, statistiques, journal d'audit |
| `agent` | Consultation/création de vols, horaires, retards, reports, annulations, observations, annonces, notifications ciblées |
| `worker` | Consultation des vols, favoris, notifications, annonces, profil |

Le rôle est **déterminé par le backend** à chaque requête. Le rôle envoyé par le client n'est jamais utilisé.

## 7. Documentation détaillée

- [Architecture](docs/ARCHITECTURE.md)
- [Configuration (variables d'environnement)](docs/CONFIGURATION.md)
- [Déploiement & Neon / Firebase / APK](docs/DEPLOYMENT.md)
- [Base de données & sauvegardes](docs/DATABASE.md)
