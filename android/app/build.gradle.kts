// Applies required plugins for Android application compilation and Flutter integration
plugins {
    // Android application Gradle plugin
    id("com.android.application")
    // Flutter Gradle integration plugin (provides Built-in Kotlin in Flutter 3.50+)
    id("dev.flutter.flutter-gradle-plugin")
}

// Configures Android compile parameters, signing, and package properties
android {
    // Unique package namespace matching AndroidManifest.xml
    namespace = "com.citiyzen.voice_assistant_controller"
    // Sets compile SDK version automatically from Flutter SDK configuration
    compileSdk = flutter.compileSdkVersion
    // Sets NDK version automatically from Flutter SDK configuration
    ndkVersion = flutter.ndkVersion

    // Configures Java compiler compatibility targeting Java 17
    compileOptions {
        // Sets Java source compatibility
        sourceCompatibility = JavaVersion.VERSION_17
        // Sets Java target bytecode compatibility
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Default configuration values across all Android build variants
    defaultConfig {
        // Unique application ID for Android OS package manager and Play Store
        applicationId = "com.citiyzen.voice_assistant_controller"
        // Minimum SDK set to API 21 (Android 5.0 Lollipop)
        minSdk = flutter.minSdkVersion
        // Target SDK version
        targetSdk = flutter.targetSdkVersion
        // Internal version code resolved from pubspec.yaml
        versionCode = flutter.versionCode
        // User-facing version name resolved from pubspec.yaml
        versionName = flutter.versionName
    }

    // Configures build type settings (Debug / Release)
    buildTypes {
        // Production release configuration
        release {
            // Signs release APK with standard debug key for immediate testing on devices
            signingConfig = signingConfigs.getByName("debug")
            // Disables ProGuard code shrinking for smooth reflection and fast compilation
            isMinifyEnabled = false
            // Disables resource shrinking
            isShrinkResources = false
        }
    }
}

// Configures Kotlin JVM compiler options targeting JVM 17
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// Configures Flutter source directory path
flutter {
    source = "../.."
}
