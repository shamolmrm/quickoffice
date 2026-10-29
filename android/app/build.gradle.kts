import java.util.Properties

// Play upload key (android/key.properties), used when QS_UPLOAD=1.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val useUploadKey = System.getenv("QS_UPLOAD") == "1" && keyProps.isNotEmpty()

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.quickoffice.pro"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.quickoffice.pro"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] =
            (project.findProperty("ADMOB_APP_ID") as String?) ?: "ca-app-pub-3940256099942544~3347511713"
    }

    buildFeatures {
        resValues = true
    }

    // free = ads + optional Premium purchase; pro = paid app, everything unlocked.
    flavorDimensions += "tier"
    productFlavors {
        create("free") {
            dimension = "tier"
            resValue("string", "app_name", "QuickOffice")
        }
        create("pro") {
            dimension = "tier"
            applicationIdSuffix = ".premium"
            resValue("string", "app_name", "QuickOffice Premium")
        }
    }

    signingConfigs {
        create("upload") {
            if (keyProps.isNotEmpty()) {
                storeFile = rootProject.file(keyProps.getProperty("storeFile").removePrefix("../"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (useUploadKey) "upload" else "debug")
            // R8 strips classes that plugins load by reflection.
            isMinifyEnabled = false
            isShrinkResources = false
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