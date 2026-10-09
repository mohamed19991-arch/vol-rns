# VOL-RNS — Application mobile (client Android)

Application Flutter (Material 3) du système de gestion hebdomadaire des vols
**VOL-RNS**. Toute l'interface est en **français**.

- Format de date : **JJ/MM/AAAA**
- Format d'heure : **24 h (HH:mm)**
- Fuseau de référence : **Africa/Algiers** — l'application affiche les dates et
  heures telles qu'envoyées par le backend (aucun calcul de fuseau côté client).
- Le **rôle** de l'utilisateur provient exclusivement du backend (réponse de
  connexion / `/me/`) : il n'est jamais choisi dans l'application.

## Prérequis

- Flutter (SDK Dart `>=3.3.0 <4.0.0`)
- Android SDK / un appareil ou émulateur Android

## Configuration de l'URL de l'API

L'URL de base de l'API est injectée à la compilation via `--dart-define`. La
valeur par défaut pointe vers l'hôte de l'émulateur Android :

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

Pour un appareil physique sur le même réseau, utilisez l'IP de la machine qui
héberge le backend :

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000/api
```

> Émulateur Android : `10.0.2.2` correspond à `localhost` de la machine hôte.

## Notifications push (Firebase)

Aucune clé privée n'est stockée dans l'application. Firebase est configuré côté
Android avec le fichier **`android/app/google-services.json`**.

1. Téléchargez `google-services.json` depuis la console Firebase
   (projet lié au backend VOL-RNS).
2. Placez-le à l'emplacement exact :
   `android/app/google-services.json`
3. Ne commitez jamais ce fichier : il est propre à chaque environnement.
   Un fichier `android/app/.gitkeep` marque l'emplacement attendu.

Si le fichier est absent, l'application démarre normalement **sans** les
notifications push (l'initialisation Firebase est encapsulée dans un
`try/catch`).

Les jetons FCM sont transmis au backend via `POST /devices/` et désenregistrés
(`POST /devices/unregister/`) à la déconnexion.

## Permissions Android

Déclarez les permissions suivantes dans
`android/app/src/main/AndroidManifest.xml` :

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

- `INTERNET` : appels à l'API.
- `POST_NOTIFICATIONS` : affichage des notifications locales en avant-plan
  (Android 13+). La permission est également demandée à l'exécution.

## Commandes

```bash
# Récupérer les dépendances
flutter pub get

# Lancer l'application (mode debug)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api

# Construire un APK de production
flutter build apk --release --dart-define=API_BASE_URL=https://api.exemple.com/api

# Construire un App Bundle (Google Play)
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.exemple.com/api
```

## Architecture

```
lib/
  main.dart                 # bootstrap (Firebase tolérant aux pannes) + providers
  app.dart                  # MaterialApp, providers, navigation par rôle
  core/                     # config, thème, constantes FR, formatage, widgets partagés
  data/
    models/                 # modèles (fromJson)
    api/                    # dio_client + une classe par domaine de l'API
    services/               # session_store (jetons chiffrés), fcm_service
  state/                    # auth_state, flights_state, notifications_state (ChangeNotifier)
  features/
    auth/                   # connexion, mot de passe oublié
    worker/                 # espace travailleur
    agent/                  # espace agent (gestion vols, annonces, notifications)
    admin/                  # espace administrateur
```

### Sécurité

- Les jetons JWT sont stockés dans le **keystore Android** via
  `flutter_secure_storage` (aucun secret backend n'est embarqué).
- Le client Dio ajoute automatiquement l'en-tête `Authorization: Bearer`, tente
  **un seul** rafraîchissement sur erreur `401` (`/auth/refresh/`) puis rejoue la
  requête ; en cas d'échec la session est effacée et l'utilisateur est déconnecté.
- Les erreurs API (`{"error": {"message": ...}}`) sont converties en messages
  français affichables dans les snackbars.
- Les actions sensibles (annulation / report de vol, envoi de notification,
  suppression / désactivation d'utilisateur) demandent une confirmation.
- L'interface masque les actions non autorisées selon le rôle, **mais le backend
  reste l'autorité** (notamment : un agent ne peut jamais créer d'administrateur).
