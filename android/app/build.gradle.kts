import java.net.URI
import java.nio.file.FileSystems
import java.nio.file.Files
import java.nio.file.StandardCopyOption

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.newFolder"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.newFolder"
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        manifestPlaceholders["applicationName"] = "io.flutter.app.FlutterApplication"
    }

    buildTypes.all {
        multiDexKeepFile = file("multidex-keep.txt")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.7.4"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.9.24")
    implementation("androidx.multidex:multidex:2.0.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

android.applicationVariants.all {
    val variantName = name
    val capitalizedVariant = variantName.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }

    val ensureFlutterLibsJarTask = tasks.register("ensureFlutterLibsJar${capitalizedVariant}") {
        dependsOn("compile${capitalizedVariant}JavaWithJavac")
        doLast {
            val jarFile = project.layout.buildDirectory.file("intermediates/flutter/${variantName}/libs.jar").get().asFile
            if (!jarFile.exists()) {
                return@doLast
            }

            val classesDir = project.layout.buildDirectory
                .dir("intermediates/javac/${variantName}/compile${capitalizedVariant}JavaWithJavac/classes")
                .get()
                .asFile

            if (!classesDir.exists()) {
                return@doLast
            }

            val pluginClassesDir = classesDir.toPath().resolve("io/flutter/plugins")
            if (!Files.exists(pluginClassesDir)) {
                return@doLast
            }

            val jarUri = URI.create("jar:" + jarFile.toURI().toString())
            val env = mapOf("create" to "false")
            FileSystems.newFileSystem(jarUri, env).use { fs ->
                Files.walk(pluginClassesDir).use { paths ->
                    paths.filter { Files.isRegularFile(it) }.forEach { source ->
                        val relative = pluginClassesDir.relativize(source).toString().replace("\\", "/")
                        val target = fs.getPath("/io/flutter/plugins/$relative")
                        if (target.parent != null) {
                            Files.createDirectories(target.parent)
                        }
                        Files.copy(source, target, StandardCopyOption.REPLACE_EXISTING)
                    }
                }
            }
        }
    }

    tasks.matching { it.name.equals("assemble${capitalizedVariant}", ignoreCase = true) }.configureEach {
        dependsOn(ensureFlutterLibsJarTask)
    }
}
