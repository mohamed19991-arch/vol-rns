# Configuration — variables d'environnement

Le fichier `.env` est **la seule source des secrets**. Il est exclu de Git
(voir `.gitignore`). Un modèle sans secret est fourni : [.env.example](file:///c:/Users/Adm/Documents/trae_projects/VOL_RNS/backend/.env.example).

## Backend (`backend/.env`)

| Variable | Obligatoire | Description |
| --- | --- | --- |
| `DJANGO_SETTINGS_MODULE` | oui | `config.settings.development` en local, `config.settings.production` en ligne |
| `DJANGO_SECRET_KEY` | oui (prod) | Chaîne aléatoire longue (≥ 50 caractères) |
| `DJANGO_DEBUG` | oui | `True` en local, `False` en production |
| `DJANGO_ALLOWED_HOSTS` | oui (prod) | Hôtes autorisés, séparés par des virgules |
| `DATABASE_URL` | oui (prod) | Chaîne de connexion Neon PostgreSQL (voir ci-dessous) |
| `DB_SSL_DISABLE` | non | `True` uniquement pour un PostgreSQL local sans SSL |
| `CORS_ALLOWED_ORIGINS` | non | Origines autorisées (séparées par des virgules) |
| `JWT_ACCESS_TOKEN_LIFETIME_MINUTES` | non | Durée du jeton d'accès (défaut 60) |
| `JWT_REFRESH_TOKEN_LIFETIME_DAYS` | non | Durée du refresh token (défaut 7) |
| `FIREBASE_CREDENTIALS_FILE` | non | Chemin du fichier JSON du compte de service |
| `FIREBASE_CREDENTIALS_BASE64` | non | Alternative : JSON encodé en base64 |
| `FIREBASE_PROJECT_ID` | non | Identifiant du projet Firebase |
| `DEFAULT_FROM_EMAIL` | non | Expéditeur des e-mails |
| `PASSWORD_RESET_RETURN_TOKEN` | non | `True` en dev : renvoie `uid`/`token` dans la réponse (jamais en prod) |

### Générer une clé secrète

```bash
python -c "import secrets; print(secrets.token_urlsafe(64))"
```

### Format de `DATABASE_URL` (Neon)

```
postgresql://<utilisateur>:<mot_de_passe>@<hote>/<base>?sslmode=require
```

Exemple (valeurs factices) :

```
DATABASE_URL=postgresql://neondb_owner:motdepasse@ep-cool-name-123456.eu-central-1.aws.neon.tech/neondb?sslmode=require
```

Le SSL est activé automatiquement (`ssl_require`) sauf si `DB_SSL_DISABLE=True`.

## Mobile (Flutter)

Aucun secret n'est stocké dans l'application. La configuration se limite à l'URL de l'API,
fournie à la compilation :

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
flutter build apk --release --dart-define=API_BASE_URL=https://mon-backend.exemple.com/api
```

- `10.0.2.2` = adresse de la machine hôte vue depuis l'émulateur Android.
- Pour un appareil physique, utilisez l'adresse IP locale de la machine (ex. `192.168.1.20`).

Le fichier `android/app/google-services.json` (Firebase) n'est **pas** un secret
au sens serveur : il est nécessaire au client FCM mais ne contient aucune clé privée.
Il reste exclu de Git par précaution.

## Priorité de chargement

1. Variables d'environnement du système (hébergeur, CI).
2. Fichier `.env` (développement local).

En production, définissez les variables dans l'interface de l'hébergeur plutôt que
de déposer un `.env` sur le disque.
