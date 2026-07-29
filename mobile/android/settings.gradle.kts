pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // 9.0.1's built-in-Kotlin support (which mobile_scanner's own
    // android/build.gradle relies on for library modules under AGP 9 -
    // see its `if (agpMajor < 9) apply plugin: 'kotlin-android'` guard)
    // was broken by upstream bug #471410336 ("AGP 9.0.0-rc01 doesn't
    // resolve Kotlin libraries via kotlin() function"), which surfaced
    // as `Could not find method kotlin()` in mobile_scanner's build.
    // Fixed in 9.1.0-alpha05, so 9.1.0+ is required - paired with
    // Gradle 9.3.1 below, which is 9.1.0's own minimum requirement.
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
