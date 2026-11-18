// Declares artifact repositories across all subprojects and build modules
allprojects {
    repositories {
        // Google Maven repository for AndroidX artifacts
        google()
        // Maven Central repository for open-source libraries
        mavenCentral()
    }
}

// Redirects Gradle build output directory to the standard root ../../build location
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Redirects each individual subproject build output directory
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Ensures all subprojects evaluate the app module dependencies first
subprojects {
    project.evaluationDependsOn(":app")
}

// Registers clean task to delete build artifacts during flutter clean
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
