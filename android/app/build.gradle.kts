plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.nabbeh"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.nabbeh"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Firebase BOM - يحدد إصدارات Firebase تلقائياً
    implementation(platform("com.google.firebase:firebase-bom:32.7.4"))
    
    // Analytics - تتبع استخدام التطبيق
    implementation("com.google.firebase:firebase-analytics")
    
    // Auth - تسجيل الدخول (Email/Password + Google)
    implementation("com.google.firebase:firebase-auth")
    
    // Firestore - قاعدة البيانات لحفظ بيانات المستخدمين
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-storage")

}

flutter {
    source = "../.."
}