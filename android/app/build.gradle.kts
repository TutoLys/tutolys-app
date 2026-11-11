plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "ca.tutolys.tutolys_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs it, scheduled or not.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The same id as the Linux build (linux/CMakeLists.txt).
        applicationId = "ca.tutolys.tutolys_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Cleartext HTTP to the loopback 3D-village server only; a demo
        // build against a laptop's dev-stack over the LAN sets
        // TUTOLYS_DEMO_LAN=1 and may reach any host in cleartext (ADR 0127).
        manifestPlaceholders["networkSecurityConfig"] =
            if (System.getenv("TUTOLYS_DEMO_LAN") == "1") {
                "network_security_demo_lan"
            } else {
                "network_security_config"
            }
    }

    buildTypes {
        release {
            // Demo builds only: signed with the debug key so the APK installs.
            // A store release needs a real upload key (#9-style decision).
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
