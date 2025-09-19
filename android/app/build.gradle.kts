import java.io.File
import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException
import org.gradle.api.Project

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties().apply {
    val propertiesFile = rootProject.file("local.properties")
    if (propertiesFile.exists()) {
        FileInputStream(propertiesFile).use(::load)
    }
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use(::load)
    }
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode")?.toIntOrNull() ?: 1
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0.0"

var isReleaseSigningConfigured = false

fun expandHomeDirectory(path: String): String? {
    if (!path.startsWith("~")) {
        return null
    }

    val homeDirectory = System.getProperty("user.home") ?: return null
    val remainder = path.substring(1).trimStart('/', '\\')
    return if (remainder.isEmpty()) {
        homeDirectory
    } else {
        File(homeDirectory, remainder).path
    }
}

fun resolveKeystorePath(
    project: Project,
    storeFilePath: String,
    keystorePropertiesFile: File,
): File {
    val trimmedPath = storeFilePath.trim()
    if (trimmedPath.isEmpty()) {
        throw GradleException("The storeFile entry in key.properties must not be blank when release signing is configured.")
    }

    val pathVariants = linkedSetOf(trimmedPath, trimmedPath.replace('\\', '/'))
    expandHomeDirectory(trimmedPath)?.let(pathVariants::add)
    expandHomeDirectory(trimmedPath.replace('\\', '/'))?.let(pathVariants::add)

    val candidateFiles = linkedSetOf<File>()
    for (variant in pathVariants) {
        val absoluteByFile = File(variant)
        val isWindowsAbsolute = WINDOWS_ABSOLUTE_PATH_PATTERN.matches(variant)
        if (absoluteByFile.isAbsolute || isWindowsAbsolute) {
            candidateFiles += absoluteByFile
            continue
        }

        candidateFiles += project.rootProject.file(variant)
        candidateFiles += project.file(variant)
        keystorePropertiesFile.parentFile?.resolve(variant)?.let(candidateFiles::add)
    }

    val existingKeystore = candidateFiles.firstOrNull { it.exists() }
    if (existingKeystore != null) {
        return existingKeystore
    }

    val searchedLocations = candidateFiles.joinToString(
        separator = System.lineSeparator() + "  - ",
        prefix = System.lineSeparator() + "  - "
    ) { it.path }

    throw GradleException(
        "The release keystore declared in key.properties could not be found. Checked:$searchedLocations"
    )
}

private val WINDOWS_ABSOLUTE_PATH_PATTERN = Regex("""^[a-zA-Z]:[\\/].*""")

android {
    namespace = "com.example.mydent_app"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.mydent_app"
        minSdk = 21
        targetSdk = 35
        versionCode = flutterVersionCode
        versionName = flutterVersionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties.getProperty("storeFile")
            val storePassword = keystoreProperties.getProperty("storePassword")
            val keyAlias = keystoreProperties.getProperty("keyAlias")
            val keyPassword = keystoreProperties.getProperty("keyPassword")

            if (!storeFilePath.isNullOrBlank() &&
                !storePassword.isNullOrBlank() &&
                !keyAlias.isNullOrBlank() &&
                !keyPassword.isNullOrBlank()
            ) {
                val keystore = resolveKeystorePath(project, storeFilePath, keystorePropertiesFile)
                storeFile = keystore
                this.storePassword = storePassword
                this.keyAlias = keyAlias
                this.keyPassword = keyPassword
                isReleaseSigningConfigured = true
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (isReleaseSigningConfigured) {
                signingConfigs.getByName("release")
            } else {
                println("Warning: Release signing is not configured. Using the debug keystore instead.")
                signingConfigs.getByName("debug")
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

flutter {
    source = "../.."
}
