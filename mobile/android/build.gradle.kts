allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// mobile_scanner's own android/build.gradle only self-applies the
// classic kotlin-android plugin when AGP's major version is < 9 (its
// own guard against AGP 9's built-in Kotlin support, which is meant to
// register a `kotlin {}` extension automatically). In practice, on AGP
// 9.1.0 that extension still isn't registered for this library
// subproject, and mobile_scanner's own `kotlin { compilerOptions {...} }`
// block (android/build.gradle:97) fails with "Could not find method
// kotlin()". Force-applying the plugin here, before mobile_scanner's
// own build script evaluates, works around it without patching the
// package itself. Safe to keep even if a future mobile_scanner/AGP
// release fixes this upstream - applying an already-applied plugin
// would be the only risk, and mobile_scanner's own `agpMajor < 9`
// guard means it won't double-apply on AGP 9.
subprojects {
    if (project.name == "mobile_scanner") {
        apply(plugin = "org.jetbrains.kotlin.android")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
