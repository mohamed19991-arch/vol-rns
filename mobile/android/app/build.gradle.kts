plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase : le plugin n'est applique que si le fichier `google-services.json`
// est present dans ce dossier. Sans lui, le build reste possible (les
// notifications push sont simplement desactivees).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.volrns.vol_rns"
    compileSdk = flutter.compileSdkVersion
    // Aucun plugin de ce projet ne requiert le NDK : on ne l'exige pas.

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Requis par flutter_local_notifications (API java.time sur anciens appareils).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Identifiant unique de l'application (a aligner avec Firebase).
        applicationId = "com.volrns.vol_rns"
        // firebase_messaging et flutter_local_notifications exigent une API recente.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Support de java.time sur les appareils anterieurs a Android 8.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
