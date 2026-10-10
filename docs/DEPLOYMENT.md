# Déploiement — Neon, Firebase, hébergement, APK/AAB

> Les offres gratuites évoluent : **vérifiez toujours les limites réelles et la
> pérennité** de chaque service avant de déployer. Aucun service gratuit n'est
> garanti permanent.

## 1. Créer le projet Neon (PostgreSQL)

1. Créez un compte sur <https://console.neon.tech>.
2. **New Project** → choisissez un nom (ex. `vol-rns`), une région proche
   (ex. `eu-central-1`), une version PostgreSQL récente.
3. Neon crée une base `neondb` et un rôle propriétaire.

## 2. Récupérer la chaîne de connexion

1. Dans le tableau de bord du projet : **Connection Details**.
2. Sélectionnez **Connection string** → **Python** (ou « URI »).
3. Copiez la chaîne, du type :

```
postgresql://neondb_owner:MOT_DE_PASSE@ep-xxx-123456.eu-central-1.aws.neon.tech/neondb?sslmode=require
```

4. Conservez `?sslmode=require` (obligatoire avec Neon).

## 3. Configurer le fichier `.env`

```bash
cd backend
copy .env.example .env     # Windows
# cp .env.example .env     # Linux / macOS
```

Renseignez au minimum :

```
DJANGO_SETTINGS_MODULE=config.settings.development
DJANGO_SECRET_KEY=<clé générée>
DJANGO_DEBUG=True
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,10.0.2.2
DATABASE_URL=postgresql://neondb_owner:...@ep-xxx.eu-central-1.aws.neon.tech/neondb?sslmode=require
```

> Ne committez **jamais** le `.env`.

## 4. Installer les dépendances

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate          # Windows
# source .venv/bin/activate     # Linux / macOS
pip install -r requirements.txt
```

## 5. Exécuter les migrations

```bash
python manage.py migrate
```

Vérification de la connexion Neon : la commande doit se terminer sans erreur SSL.
En cas d'échec, contrôlez `sslmode=require` et l'exactitude du mot de passe.

## 6. Créer le compte administrateur

```bash
python manage.py seed_initial_data \
  --admin-email admin@vol-rns.local \
  --admin-password "ChangerCe MotDePasse!123"
```

Cette commande crée les 5 destinations (RNS, ORAN, ADRAR, BISKRA, BEJAIA) et
l'administrateur.

Les **horaires ne sont jamais inventés**. Pour créer le programme hebdomadaire initial
(Samedi/Dimanche/Lundi), fournissez explicitement les horaires :

```bash
python manage.py seed_initial_data \
  --admin-email admin@vol-rns.local \
  --admin-password "ChangerCeMotDePasse!123" \
  --with-initial-schedule \
  --registration-time 08:00 \
  --departure-time 10:00 \
  --arrival-time 12:00
```

Sans ces options, les trajets sont à configurer par l'administrateur depuis
l'application (ou Django Admin).

## 7. Créer le projet Firebase

1. <https://console.firebase.google.com> → **Ajouter un projet**.
2. Nom du projet (ex. `vol-rns`) → activez Google Analytics si souhaité.
3. Dans le projet : **Ajouter une application** → **Android**.
4. **Nom du package Android** : celui déclaré dans `mobile/android/app/build.gradle`
   (par défaut `com.example.vol_rns` — modifiez-le pour un identifiant unique,
   ex. `com.volrns.app`, **avant** d'enregistrer l'application dans Firebase).
5. Téléchargez **`google-services.json`**.

## 8. Configurer Firebase pour Android (client)

1. Placez le fichier dans `mobile/android/app/google-services.json`.
2. Vérifiez que `mobile/android/app/build.gradle` applique le plugin
   `com.google.gms.google-services`.
3. Ajoutez les permissions dans `mobile/android/app/src/main/AndroidManifest.xml`
   (Android 13+) :

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

4. Côté backend, générez une **clé de compte de service** :
   - Console Firebase → **Paramètres du projet** → **Comptes de service** →
     **Générer une nouvelle clé privée** → téléchargez le JSON.
   - Enregistrez-le **hors du dépôt**, par ex. `backend/secrets/firebase-service-account.json`
     (dossier exclu de Git) et renseignez :

```
FIREBASE_CREDENTIALS_FILE=secrets/firebase-service-account.json
FIREBASE_PROJECT_ID=vol-rns
```

   - Alternative sans fichier : `FIREBASE_CREDENTIALS_BASE64` (JSON encodé en base64).

> La clé privée reste **exclusivement côté serveur**. Elle ne doit jamais être
> embarquée dans l'application Android.

## 9. Configurer le serveur Django (production)

Variables à définir chez l'hébergeur :

```
DJANGO_SETTINGS_MODULE=config.settings.production
DJANGO_SECRET_KEY=<clé robuste>
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=mon-backend.exemple.com
DATABASE_URL=postgresql://...neon...?sslmode=require
CORS_ALLOWED_ORIGINS=https://mon-domaine.exemple.com
FIREBASE_CREDENTIALS_BASE64=<json base64>   # ou FIREBASE_CREDENTIALS_FILE
```

La configuration de production **refuse de démarrer** si `DATABASE_URL` est absent,
si la clé secrète est la valeur par défaut, ou si `DJANGO_DEBUG=True`.

Commandes de démarrage (exemple gunicorn) :

```bash
python manage.py migrate --noinput
python manage.py collectstatic --noinput
gunicorn config.wsgi:application --bind 0.0.0.0:$PORT
```

Hébergeurs compatibles Django avec offre gratuite (à vérifier régulièrement) :
Render, Railway, Fly.io, Koyeb. Points de vigilance : mise en veille des instances
gratuites, limites de temps CPU, bande passante, et cycle de vie des disques éphémères
(les fichiers statiques sont servis par WhiteNoise, ce qui évite ce problème).

## 10. Générer l'APK de test

```bash
cd mobile
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://mon-backend.exemple.com/api
```

Artefact : `mobile/build/app/outputs/flutter-apk/app-release.apk`.

Pour un test local de bout en bout :

```bash
# backend accessible depuis l'émulateur
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

## 11. Générer l'Android App Bundle (Play Store)
1. Créez une clé de signature et `mobile/android/key.properties` (exclu de Git).
2. Configurez la signature dans `mobile/android/app/build.gradle`.
3. Générez le bundle :

```bash
cd mobile
flutter build appbundle --release --dart-define=API_BASE_URL=https://mon-backend.exemple.com/api
```

Artefact : `mobile/build/app/outputs/bundle/release/app-release.aab`.

## 12. Tests de bout en bout

1. Le backend est joignable : `GET https://mon-backend.exemple.com/api/schema/` → 200.
2. Connexion administrateur depuis l'application → tableau de bord admin.
3. Création d'une destination, d'un créneau hebdomadaire, génération d'une semaine.
4. Création d'un vol daté par un agent.
5. Un travailleur ajoute un favori sur ce trajet ; l'agent déclare un **retard** →
   le travailleur reçoit une notification ; l'état de lecture se met à jour.
6. Publication d'une annonce urgente → notification reçue.
7. Vérification de l'historique (`/flights/{id}/history/` et journal d'audit).
8. Contrôle des journaux serveur (aucune erreur 500).

## 13. Limites des offres gratuites et sauvegardes

- Neon (offre gratuite) : limite de stockage, calcul suspendu après inactivité,
  historique de restauration limité. **Ne supposez pas de sauvegardes illimitées.**
- Voir [DATABASE.md](DATABASE.md) pour l'export/restauration via `backup_data`.
- L'hébergeur backend peut mettre l'instance en veille : le premier appel peut être lent.

## 14. Notes de compilation Android (environnement local)

Le projet a été compilé avec succès (APK release de 54,1 Mo) avec la configuration
suivante, appliquée dans `mobile/android/` :

| Fichier | Réglage | Raison |
| --- | --- | --- |
| `app/build.gradle.kts` | `minSdk = 23` | exigé par `firebase_messaging` / `flutter_local_notifications` |
| `app/build.gradle.kts` | `isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs:2.1.4` | exigé par `flutter_local_notifications` |
| `app/build.gradle.kts` | `ndkVersion` retiré | aucun plugin du projet n'utilise de code natif |
| `build.gradle.kts` (racine) | `compileSdkVersion 36` forcé sur tous les sous-projets | les dépendances AndroidX/Firebase exigent l'API ≥ 34 |
| `gradle.properties` | `kotlin.compiler.execution.strategy=in-process` | évite un daemon Kotlin séparé |

Si votre environnement refuse l'écriture dans le SDK Android global, vous pouvez
utiliser un SDK local au projet (`ANDROID_HOME` / `ANDROID_SDK_ROOT`) ainsi qu'un
cache Pub local (`PUB_CACHE`) — les deux sont exclus de Git.

Commande de build complète :

```powershell
$env:JAVA_HOME='<chemin JDK 17+>'
$env:ANDROID_HOME='<chemin Android SDK (api 36 + build-tools 36)>'
$env:ANDROID_SDK_ROOT=$env:ANDROID_HOME
flutter build apk --release --dart-define=API_BASE_URL=https://mon-backend.exemple.com/api
```

L'APK généré est copié dans `dist/vol-rns-release.apk`.

> Signature : la configuration release utilise pour l'instant la clé de **debug**
> (voir `signingConfig = signingConfigs.getByName("debug")`). Créez une clé de
> release avant toute publication sur le Play Store.

## 15. Déploiement du backend sur Render (recommandé) + APK

Objectif : que le téléphone joigne le backend **sans que le PC soit allumé**.

### 15.1 Pousser le code sur GitHub

Git est disponible en version **portable** dans le projet
(`.tools\PortableGit\cmd\git.exe`) : aucune installation système n'est
nécessaire. Le dépôt est **déjà initialisé** et le code **déjà committé** ; il
ne reste qu'à créer le dépôt distant et pousser :

```powershell
$git = "c:\Users\Adm\Documents\trae_projects\VOL_RNS\.tools\PortableGit\cmd\git.exe"
cd c:\Users\Adm\Documents\trae_projects\VOL_RNS
& $git remote add origin https://github.com/<votre-compte>/vol-rns.git
& $git push -u origin main
```

> Le fichier `.env`, `dist/`, `.tools/`, `.android-sdk/` et `.pub-cache/` sont
> exclus par `.gitignore` : aucun secret ne sera publié.

### 15.2 Créer la base Neon

Voir la section 7, étapes 1 à 4 : projet sur <https://console.neon.tech>, puis
copiez la chaîne de connexion (`postgresql://…?sslmode=require`).

### 15.3 Créer le service Render

1. <https://render.com> → **New +** → **Blueprint** → sélectionnez votre dépôt.
2. Render lit [render.yaml](file:///c:/Users/Adm/Documents/trae_projects/VOL_RNS/render.yaml) et crée le service `vol-rns-backend`
   (`rootDir: backend`, `buildCommand: ./build.sh`, plan **free**).
3. Renseignez les variables demandées :
   - `DATABASE_URL` → la chaîne Neon
   - `CORS_ALLOWED_ORIGINS` → l'origine de votre futur site (ou laissez vide)
   - `FIREBASE_PROJECT_ID`, `FIREBASE_CREDENTIALS_BASE64` → seulement si vous
     activez les notifications push
4. `DJANGO_SECRET_KEY` est **généré automatiquement** par Render (`generateValue`).
5. `DJANGO_ALLOWED_HOSTS=.onrender.com` couvre le domaine Render ; le domaine
   exact est aussi ajouté à chaud via `RENDER_EXTERNAL_HOSTNAME`.

Le `build.sh` installe les dépendances, exécute `collectstatic` et `migrate` à
chaque déploiement.

### 15.4 Compte administrateur et données

Le **Shell n'existe pas sur l'offre gratuite Render**. On crée donc les données
**depuis le PC**, en pointant `DATABASE_URL` vers la base Neon (Neon est
accessible depuis Internet) :

```powershell
cd c:\Users\Adm\Documents\trae_projects\VOL_RNS\backend
$env:DATABASE_URL="postgresql://neondb_owner:XXX@ep-xxx.eu-central-1.aws.neon.tech/neondb?sslmode=require"
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py seed_initial_data `
  --admin-email admin@vol-rns.local `
  --admin-password "ChangerCeMotDePasse!123"
```

`migrate` et `seed_initial_data` sont **idempotents** : on peut les relancer
sans risque. Une fois le service Render **Live**, le même compte fonctionne
dans l'application.

Pour reprendre les données créées localement (SQLite) :

```powershell
# 1. sur le PC (SQLite)
.\.venv\Scripts\python.exe manage.py backup_data --output backup.json
# 2. avec DATABASE_URL = Neon (base hebergee)
.\.venv\Scripts\python.exe manage.py loaddata backup.json
```

### 15.5 Vérifier

```
https://<votre-service>.onrender.com/api/schema/   -> 200
https://<votre-service>.onrender.com/api/docs/     -> Swagger
```

### 15.6 Régénérer l'APK avec l'URL publique

```powershell
cd c:\Users\Adm\Documents\trae_projects\VOL_RNS\mobile
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
$env:ANDROID_HOME='C:\Users\Adm\Documents\trae_projects\VOL_RNS\.android-sdk'
$env:ANDROID_SDK_ROOT=$env:ANDROID_HOME
$env:PUB_CACHE='C:\Users\Adm\Documents\trae_projects\VOL_RNS\.pub-cache'
flutter build apk --release --dart-define=API_BASE_URL=https://<votre-service>.onrender.com/api
```

Puis installez `mobile\build\app\outputs\flutter-apk\app-release.apk` sur le
téléphone. **Attention** : un compte gratuit Render met le service en veille
après ~15 min d'inactivité ; le premier appel peut prendre ~30 à 60 s.


