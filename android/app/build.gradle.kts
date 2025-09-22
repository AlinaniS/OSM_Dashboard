plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Unique namespace for your app
    namespace = "com.example.open_dashboard"
    
    // Compile SDK version: should use the latest supported by Flutter
    compileSdk = flutter.compileSdkVersion

    // Use same NDK version as Flutter (needed only if using native code)
    ndkVersion = flutter.ndkVersion

    // Java compatibility
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    // Kotlin options
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Unique app identifier
        applicationId = "com.example.open_dashboard"

        // Minimum SDK version (Android 5.1.1 = API 22)
        minSdk = 22

        // Target SDK (latest recommended)
        targetSdk = 34

        // Flutter-managed versioning
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // MultiDex enables more than 64K methods if your dependencies are large
        multiDexEnabled = true
    }

    buildTypes {
        getByName("release") {
            // For now, use debug signing (change for production release)
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false // Disable code shrinking for simplicity
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Optional: if you use Flutter plugins with native Android code
    buildFeatures {
        viewBinding = true
    }

    // Optional: packaging options to avoid conflicts with some plugins
    packagingOptions {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/NOTICE",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE.txt"
            )
        }
    }
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1") // Required for MultiDex support
    implementation(kotlin("stdlib")) // Kotlin standard library
}


flutter {
    source = "../.."
}
