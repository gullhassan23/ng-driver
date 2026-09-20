import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------
// Load key.properties for release signing
// Looks in android/app/ first, then android/
// ---------------------------------------------------------
val keystorePropertiesFile = listOf(
    file("key.properties"),
    rootProject.file("key.properties"),
).firstOrNull { it.exists() }

val keystoreProperties = Properties()
if (keystorePropertiesFile != null) {
    FileInputStream(keystorePropertiesFile).use {
        keystoreProperties.load(it)
    }
}

// ---------------------------------------------------------
// Google Maps API key (local.properties or -P / gradle.properties)
// ---------------------------------------------------------
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    FileInputStream(localPropertiesFile).use { localProperties.load(it) }
}

val envProperties = Properties()
val envFile = rootProject.file("../.env")
if (envFile.exists()) {
    FileInputStream(envFile).use { envProperties.load(it) }
}

val googleMapsApiKey =
    localProperties.getProperty("GOOGLE_MAPS_API_KEY")
        ?: envProperties.getProperty("GOOGLE_MAPS_API_KEY")
        ?: (project.findProperty("GOOGLE_MAPS_API_KEY") as String?)
        ?: ""

android {
    namespace = "ngtownride.driver"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ngtownride.driver"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsApiKey
    }

    signingConfigs {
        if (keystorePropertiesFile != null) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?

                storeFile = (keystoreProperties["storeFile"] as String?)?.let { path ->
                    val fromApp = file(path)
                    if (fromApp.exists()) fromApp else rootProject.file(path)
                }

                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile != null) {
                signingConfigs.getByName("release")
            } else {
                throw GradleException(
                    "Release signing is missing. Add android/app/key.properties " +
                        "(or android/key.properties) and a release keystore. " +
                        "Play Console rejects debug-signed AABs."
                )
            }

            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        )
    }
}

flutter {
    source = "../.."
}