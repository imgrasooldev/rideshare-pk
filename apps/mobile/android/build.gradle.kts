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

// With AGP 9 + android.builtInKotlin=false, plugin packages (e.g. package_info_plus)
// skip applying the Kotlin plugin themselves and expect the toolchain to provide it.
// Newer Flutter Gradle plugins do this automatically; apply it here for older ones.
subprojects {
    plugins.withId("com.android.library") {
        if (!project.plugins.hasPlugin("org.jetbrains.kotlin.android")) {
            project.apply(plugin = "org.jetbrains.kotlin.android")
        }
    }
    plugins.withId("com.android.application") {
        if (!project.plugins.hasPlugin("org.jetbrains.kotlin.android")) {
            project.apply(plugin = "org.jetbrains.kotlin.android")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
