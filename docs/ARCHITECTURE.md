# Architecture — VOL-RNS

## 1. Vue d'ensemble

```
┌────────────────────┐        HTTPS / JSON        ┌──────────────────────┐
│  Application       │  ───────────────────────▶  │  Backend Django REST │
│  Android (Flutter) │  ◀───────────────────────  │  (WSGI / gunicorn)   │
└─────────┬──────────┘        JWT Bearer          └───────────┬──────────┘
          │                                                   │
          │ Firebase Cloud Messaging                           │ psycopg (SSL)
          ▼                                                   ▼
┌────────────────────┐                            ┌──────────────────────┐
│  Firebase (FCM)    │                            │  Neon PostgreSQL     │
│  (push Android)    │                            │  (offre gratuite)    │
└────────────────────┘                            └──────────────────────┘
```

Séparation stricte des responsabilités :

| Couche | Responsabilité |
| --- | --- |
| Flutter | Interface, navigation, affichage, saisie, réception des push. **Aucun secret.** |
| Django REST | Règles métier, permissions par rôle, validation, ciblage des notifications. |
| PostgreSQL (Neon) | Persistance, intégrité, relations, index. |
| Firebase | Transport des notifications push vers les appareils Android. |

## 2. Backend — organisation

```
backend/
├── manage.py
├── requirements.txt
├── .env.example
├── config/
│   ├── settings/{base,development,production}.py
│   ├── urls.py          # routage global + Swagger
│   ├── wsgi.py / asgi.py
├── apps/
│   ├── core/            # TimeStampedModel, AuditLog, pagination, exceptions, permissions
│   ├── accounts/        # User, Profile, auth JWT, gestion utilisateurs
│   ├── flights/         # Destination, WeeklySchedule, Flight, FlightChangeLog, Favorite
│   └── notifications/   # Announcement, Notification, NotificationRecipient, FCMDevice
└── apps/*/tests.py      # tests automatisés
```

### Applications

- **core** : modèles abstraits, journal d'audit, pagination standardisée, gestion homogène
  des erreurs, permissions de rôle réutilisables, commande `backup_data`.
- **accounts** : utilisateur personnalisé à e-mail unique, profil et préférences,
  authentification JWT (login/refresh/logout), réinitialisation de mot de passe,
  gestion des utilisateurs et des rôles (administrateur).
- **flights** : destinations, programme hebdomadaire récurrent, vols datés, historique
  des modifications, favoris, statistiques.
- **notifications** : annonces, notifications et état de lecture par destinataire,
  jetons FCM des appareils, service d'envoi et de ciblage.

## 3. Modèle de données

| Modèle | Rôle | Points clés |
| --- | --- | --- |
| `User` | Compte | e-mail unique, `role` ∈ {admin, agent, worker}, mot de passe haché par Django |
| `Profile` | Préférences | langue, notifications push, matricule, poste |
| `Destination` | Ville/aéroport | `code` unique (RNS, ORAN, ADRAR, BISKRA, BEJAIA…) |
| `WeeklySchedule` | Programme récurrent | jour + trajet + horaires, contrainte d'unicité par créneau |
| `Flight` | Vol daté | date + jour déduit, statut, observation, **anciens horaires**, auteur/modif |
| `FlightChangeLog` | Traçabilité | chaque changement (création, horaire, statut, observation…) |
| `Favorite` | Favoris | destination / trajet / vol, avec `notifications_enabled` |
| `Announcement` | Annonces | catégorie, priorité, cible, brouillon/publié, expiration |
| `Notification` | Notification | contenu, catégorie, cible, vol, `dedup_key`, compteurs d'envoi |
| `NotificationRecipient` | État de lecture | unique (notification, utilisateur) |
| `FCMDevice` | Jeton appareil | `token` unique, plateforme, actif/inactif |
| `AuditLog` | Journal | auteur, action, entité, IP, horodatage |

### Distinction programme / vol daté

- `WeeklySchedule` décrit le **programme habituel** (récurrent, sans date).
- `Flight` décrit un **vol à une date précise**, relié optionnellement à un `WeeklySchedule`.
- Une modification exceptionnelle d'un `Flight` (report, nouvel horaire) **ne modifie jamais**
  le `WeeklySchedule` correspondant : les semaines suivantes restent inchangées.

## 4. API REST

Toutes les routes sont préfixées par `/api/`.

```
/auth/login/  /auth/refresh/  /auth/logout/
/auth/password-reset/  /auth/password-reset/confirm/
/me/  /me/change-password/
/users/  /users/{id}/set_password/  /audit-logs/
/destinations/
/weekly-schedules/  /weekly-schedules/week/  /weekly-schedules/generate/
/flights/  /flights/today/  /flights/upcoming/  /flights/{id}/history/
/flights/{id}/delay/  /flights/{id}/postpone/  /flights/{id}/cancel/  /flights/{id}/observe/
/favorites/  /favorites/{id}/toggle_notifications/
/announcements/  /announcements/{id}/publish/  /announcements/{id}/unpublish/
/notifications/  /notifications/unread_count/  /notifications/{id}/mark_read/  /notifications/mark_all_read/
/notification-management/  /notification-management/{id}/recipients/  /notification-management/{id}/resend/
/devices/  /devices/unregister/
/stats/flights/
```

- Pagination : `?page=`, `?page_size=` (max 100).
- Erreurs homogènes : `{"error": {"status", "code", "message", "fields"}}`.
- Documentation interactive : `/api/docs/` (Swagger UI), `/api/redoc/`, schéma `/api/schema/`.

## 5. Sécurité

- Mots de passe hachés par Django (PBKDF2) + validateurs de robustesse.
- JWT signés, rotation et blacklist des refresh tokens.
- Permissions vérifiées **côté serveur** à chaque requête (`IsAdmin`, `IsAgent`, `IsAgentOrReadOnly`).
- Limitation de débit sur la connexion (10/min) et la réinitialisation (5/h).
- Journal d'audit des actions sensibles (connexions, rôles, modifications).
- HTTPS forcé, cookies sécurisés, HSTS en production.
- Secrets exclusivement dans `.env` (jamais committé).
- Les clés privées Firebase restent côté serveur ; l'app Android ne reçoit que `google-services.json`.

## 6. Notifications — flux

1. L'agent modifie un vol (retard, report, annulation, horaire…).
2. Le backend **enregistre d'abord** la modification et son historique (`FlightChangeLog`).
3. Une `Notification` est créée en base **avant** l'envoi push.
4. Les destinataires sont résolus par ciblage (tous / destination / trajet / vol),
   via les `Favorite` des travailleurs.
5. Le push FCM est envoyé immédiatement aux jetons actifs.
6. Les jetons invalides sont désactivés ; les erreurs transitoires sont rejouées (3 tentatives).
7. Les échecs de notification **ne bloquent jamais** l'opération métier.

### Anti-doublon

Chaque notification automatique porte une clé `dedup_key` (ex. `flight-12-status-cancelled`).
Une clé déjà présente empêche tout renvoi. Les envois manuels peuvent fournir une clé explicite.

## 7. Gestion des erreurs et résilience mobile

- Indicateurs de chargement, écrans d'erreur avec « Réessayer », états vides.
- Rafraîchissement automatique des données après une modification.
- Intercepteur Dio : ajout du jeton, rafraîchissement unique sur 401 puis réessai,
  déconnexion si le rafraîchissement échoue.
- Messages d'erreur français issus du champ `error.message` du backend.
