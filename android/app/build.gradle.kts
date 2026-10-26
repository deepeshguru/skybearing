import java.io.File
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingWorkspaceRoot = rootProject.projectDir.parentFile.canonicalFile
val signingUserHome = File(System.getProperty("user.home")).canonicalFile
val signingPropertiesPathOverride = providers.environmentVariable("OFFLINE_SKY_SIGNING_PROPERTIES")
    .orNull
    ?.takeIf { it.isNotBlank() }
val signingPropertiesFile = signingPropertiesPathOverride?.let(::File)
    ?: File(signingUserHome, ".config/offline-sky/android-signing.properties")
val signingProperties = Properties()
var signingPropertiesReadFailed = false
if (signingPropertiesFile.isFile) {
    try {
        signingPropertiesFile.inputStream().use(signingProperties::load)
    } catch (_: Exception) {
        signingPropertiesReadFailed = true
    }
}

fun signingValue(propertyName: String, environmentName: String): String? =
    providers.environmentVariable(environmentName)
        .orNull
        ?.takeIf { it.isNotBlank() }
        ?: signingProperties.getProperty(propertyName)?.takeIf { it.isNotBlank() }

val releaseStoreFilePath = signingValue("storeFile", "OFFLINE_SKY_UPLOAD_STORE_FILE")
val releaseStoreFile = releaseStoreFilePath?.let(::File)
val releaseStorePassword = signingValue("storePassword", "OFFLINE_SKY_UPLOAD_STORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "OFFLINE_SKY_UPLOAD_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "OFFLINE_SKY_UPLOAD_KEY_PASSWORD")
val releaseSigningConfigured = listOf(
    releaseStoreFilePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { it != null }

fun isWithinSigningWorkspace(file: File): Boolean =
    file.canonicalFile.toPath().startsWith(signingWorkspaceRoot.toPath())

android {
    namespace = "com.offlinesky.offline_sky"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Keep this application ID unchanged after the first Play publication.
        applicationId = "com.offlinesky.offline_sky"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("productionRelease") {
                storeFile = requireNotNull(releaseStoreFile)
                storePassword = requireNotNull(releaseStorePassword)
                keyAlias = requireNotNull(releaseKeyAlias)
                keyPassword = requireNotNull(releaseKeyPassword)
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseSigningConfigured) {
                signingConfigs.getByName("productionRelease")
            } else {
                null
            }
        }
    }
}

val verifyReleaseSigning = tasks.register("verifyReleaseSigning") {
    group = "verification"
    description = "Checks that release signing inputs are complete and stored outside the workspace."
    doLast {
        if (!releaseSigningConfigured) {
            val missing = listOf(
                "OFFLINE_SKY_UPLOAD_STORE_FILE",
                "OFFLINE_SKY_UPLOAD_STORE_PASSWORD",
                "OFFLINE_SKY_UPLOAD_KEY_ALIAS",
                "OFFLINE_SKY_UPLOAD_KEY_PASSWORD",
            ).filterIndexed { index, _ ->
                listOf(
                    releaseStoreFilePath,
                    releaseStorePassword,
                    releaseKeyAlias,
                    releaseKeyPassword,
                )[index] == null
            }
            val propertiesFileNote = if (signingPropertiesReadFailed) {
                " The external signing properties file could not be read."
            } else {
                ""
            }
            throw GradleException(
                "Release signing is not configured.$propertiesFileNote Provide all four values " +
                    "through the named environment variables or an external properties file at " +
                    "~/.config/offline-sky/android-signing.properties (or set " +
                    "OFFLINE_SKY_SIGNING_PROPERTIES). Missing: ${missing.joinToString()}.",
            )
        }

        if (signingPropertiesPathOverride != null && !signingPropertiesFile.isAbsolute) {
            throw GradleException("OFFLINE_SKY_SIGNING_PROPERTIES must be an absolute path outside the workspace.")
        }
        if (isWithinSigningWorkspace(signingPropertiesFile)) {
            throw GradleException("The signing properties file must be stored outside the workspace.")
        }

        val keystore = requireNotNull(releaseStoreFile)
        if (!keystore.isAbsolute) {
            throw GradleException("OFFLINE_SKY_UPLOAD_STORE_FILE must be an absolute path outside the workspace.")
        }
        if (isWithinSigningWorkspace(keystore)) {
            throw GradleException("The upload keystore must be stored outside the workspace.")
        }
        if (!keystore.isFile || !keystore.canRead()) {
            throw GradleException("The configured upload keystore is missing or unreadable. Its path is not displayed.")
        }
    }
}

tasks.configureEach {
    val isReleaseArtifactTask = name.contains("Release", ignoreCase = true) &&
        !name.contains("Test", ignoreCase = true) &&
        listOf("assemble", "bundle", "package", "sign", "validateSigning")
            .any { prefix -> name.startsWith(prefix, ignoreCase = true) }
    if (isReleaseArtifactTask) {
        dependsOn(verifyReleaseSigning)
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
