plugins {
    id("com.android.application")
    id("kotlin-android")
    // Plugin Flutter harus diterapkan setelah Android dan Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.diary_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.14033849"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // Gunakan tanda sama dengan (=) untuk Kotlin DSL
        applicationId = "com.example.diary_app"
        
        // Menggunakan nilai dari Flutter SDK atau hardcode angka jika perlu (misal: 21)
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        
        // Akses properti flutter.versionCode dan flutter.versionName
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Menggunakan signing debug agar bisa dijalankan dengan 'flutter run --release'
            // Jika Anda sudah punya keystore asli, ganti "debug" dengan nama config release Anda.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.23")
}