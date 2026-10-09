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

// Certains plugins compilent encore contre une API ancienne (33), alors que
// leurs dependances (AndroidX/Firebase) exigent l'API 34+. On aligne tous les
// sous-projets Android sur le compileSdk de Flutter (36).
subprojects {
    fun alignCompileSdk() {
        val androidExtension = extensions.findByName("android") ?: return
        try {
            androidExtension.javaClass
                .getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                .invoke(androidExtension, 36)
        } catch (_: Exception) {
            // Extension non Android : rien a faire.
        }
    }
    if (state.executed) alignCompileSdk() else afterEvaluate { alignCompileSdk() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
