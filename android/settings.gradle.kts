// Configures plugin resolution repositories and Gradle plugin build scripts
pluginManagement {
    // Dynamically resolves the Flutter SDK path from local.properties
    val flutterSdkPath =
        run {
            // Instantiates Java Properties loader
            val properties = java.util.Properties()
            // Loads local.properties stream
            file("local.properties").inputStream().use { properties.load(it) }
            // Extracts the flutter.sdk path
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            // Asserts that Flutter SDK path exists
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            // Returns resolved path
            flutterSdkPath
        }

    // Includes the Flutter Tools Gradle logic directly from the active Flutter SDK
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    // Declares package repositories to resolve Gradle plugins
    repositories {
        // Google Maven repository for Android Gradle plugin
        google()
        // Maven Central repository for open-source dependencies
        mavenCentral()
        // Official Gradle Plugin Portal
        gradlePluginPortal()
    }
}

// Declares the top-level Gradle plugins applied across Android subprojects
plugins {
    // Applies the modern declarative Flutter plugin loader
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Android Gradle Plugin version 9.3.1 matched to Flutter 3.50 engine
    id("com.android.application") version "9.3.1" apply false
    // Kotlin Android Gradle plugin version 2.4.20
    id("org.jetbrains.kotlin.android") version "2.4.20" apply false
}

// Includes the primary application module in this Gradle multi-project build
include(":app")
