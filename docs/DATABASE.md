# Base de données — Neon PostgreSQL, migrations et sauvegardes

## 1. Connexion

- `DATABASE_URL` est lue depuis l'environnement (`backend/.env` en local).
- Le SSL est activé automatiquement (`ssl_require`) : `?sslmode=require` dans l'URL Neon.
- En **production**, `config.settings.production` refuse de démarrer sans `DATABASE_URL`
  pointant vers PostgreSQL.
- En **développement/test**, un repli SQLite local est utilisé si `DATABASE_URL` est absente.
  **SQLite ne doit jamais servir en production.**

## 2. Migrations

```bash
cd backend
python manage.py makemigrations        # génère les migrations
python manage.py migrate               # applique au schéma
python manage.py showmigrations        # état des migrations
python manage.py sqlmigrate flights 0001   # SQL d'une migration
```

Après un déploiement, exécutez systématiquement `python manage.py migrate --noinput`.

## 3. Contraintes d'intégrité et index

| Contrainte | Objectif |
| --- | --- |
| `User.email` unique | un compte par adresse e-mail |
| `uniq_weekly_slot` | pas de doublon dans le programme hebdomadaire |
| `uniq_flight_slot` | pas de vol identique (date + trajet + horaire) |
| `flight_origin_diff_destination` / `weekly_origin_diff_destination` | départ ≠ destination |
| `uniq_favorite_destination` / `uniq_favorite_route` / `uniq_favorite_flight` | pas de doublon de favori par utilisateur |
| `uniq_notification_recipient` | état de lecture unique par (notification, utilisateur) |
| `FCMDevice.token` unique | un jeton = un appareil |

Index de recherche : `flight_date + status`, `origin + destination`, `-updated_at`,
`role`, `is_active`, `category`, `user + is_read`, `-created_at`.

Les dates/heures sont stockées en tenant compte du fuseau (`USE_TZ=True`,
`TIME_ZONE=Africa/Algiers`) ; Django stocke en UTC et affiche dans le fuseau configuré.

## 4. Sauvegarde et restauration

Neon (offre gratuite) ne garantit pas de sauvegardes automatiques illimitées.
Utilisez l'export portable fourni :

```bash
# Export complet horodaté dans backups/
python manage.py backup_data

# Export vers un chemin précis
python manage.py backup_data --output backups/vol-rns-2026-03-14.json
```

Restauration :

```bash
python manage.py loaddata backups/vol-rns-2026-03-14.json
```

Recommandations :

1. Planifiez un export régulier (tâche planifiée / CI) et stockez-le **hors** de Neon
   (stockage objet, disque chiffré).
2. Vérifiez périodiquement l'exécution réelle d'une restauration sur une base de test.
3. Chiffrez les exports : ils contiennent des données personnelles.
4. Conservez plusieurs versions (rotation) et documentez la rétention.

## 5. Vérification de la connexion

```bash
python manage.py shell -c "from django.db import connection; connection.ensure_connection(); print('Connexion OK :', connection.vendor)"
```

Sortie attendue en production : `Connexion OK : postgresql`.

## 6. Bonnes pratiques

- Ne jamais modifier le schéma à la main en production : passer par les migrations.
- Toujours vérifier `python manage.py makemigrations --check --dry-run` en CI.
- Sauvegarder avant toute migration destructive.
- Limiter les rôles Neon et utiliser des mots de passe forts et rotatifs.
