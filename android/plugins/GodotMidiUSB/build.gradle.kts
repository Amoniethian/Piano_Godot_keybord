plugins {
    id("com.android.library")
}

android {
    namespace = "com.piano.godot.midi"
    compileSdk = 34

    defaultConfig {
        minSdk = 23
        targetSdk = 34
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    // Godot engine library — download from:
    // https://github.com/godotengine/godot/releases (godot-lib.4.3.stable.template_release.aar)
    // Place the AAR in: android/libs/godot-lib.aar
    compileOnly(fileTree(mapOf("dir" to "../../libs", "include" to listOf("godot-lib*.aar"))))
    implementation("androidx.annotation:annotation:1.7.1")
}
