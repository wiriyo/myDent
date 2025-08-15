plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.mydent_app"
    // compileSdk ควรเป็นเวอร์ชันล่าสุด ซึ่ง 34 ถูกต้องแล้วค่ะ
    compileSdk = 34
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.mydent_app"
        // minSdkVersion ควรเป็น 21 ขึ้นไปค่ะ
        minSdk = 21
        
        // ✨ FIX: นี่คือจุดที่สำคัญที่สุดค่ะ!
        // เราจะระบุ targetSdk เป็น 34 ไปเลยตรงๆ
        // เพื่อให้ Android รู้ว่าแอปเรารองรับ permission แบบใหม่แล้ว
        targetSdk = 34 

        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
