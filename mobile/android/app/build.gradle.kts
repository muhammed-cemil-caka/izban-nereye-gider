import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Yayın imzası. android/key.properties dosyası VARSA oradan okunur; yoksa
// debug anahtarı kullanılır ve `flutter run --release` yine çalışır.
//
// key.properties gizlidir, depoya girmez (.gitignore). Oluşturmak için:
//
//   keytool -genkey -v -keystore ~/izban-yayin.jks -keyalg RSA \
//           -keysize 2048 -validity 10000 -alias izban
//
// Sonra android/key.properties içine:
//
//   storeFile=/Users/<kullanici>/izban-yayin.jks
//   storePassword=...
//   keyAlias=izban
//   keyPassword=...
//
// Anahtarı KAYBETME: Play'e ilk yüklemeden sonra aynı anahtarla imzalamak
// zorundasın, yoksa güncelleme yayımlayamazsın.
val imzaAyarlari = Properties().apply {
    val dosya = rootProject.file("key.properties")
    if (dosya.exists()) load(FileInputStream(dosya))
}
val imzaVar = imzaAyarlari.getProperty("storeFile") != null

android {
    namespace = "com.izban.izban_nereye_gider"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.izban.izban_nereye_gider"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (imzaVar) {
            create("yayin") {
                storeFile = file(imzaAyarlari.getProperty("storeFile"))
                storePassword = imzaAyarlari.getProperty("storePassword")
                keyAlias = imzaAyarlari.getProperty("keyAlias")
                keyPassword = imzaAyarlari.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // key.properties yoksa debug anahtarı kullanılır: geliştirme
            // sürerken `flutter run --release` çalışmaya devam etsin. Play
            // Console debug anahtarıyla imzalı yüklemeyi reddeder.
            signingConfig = signingConfigs.getByName(if (imzaVar) "yayin" else "debug")

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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
