allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    // Fix for device_apps package namespace issue
    afterEvaluate {
        if (project.name == "device_apps" || project.path.contains("device_apps")) {
            var namespace: String? = null
            
            try {
                // Try to get namespace from AndroidManifest.xml
                val manifestFile = project.file("src/main/AndroidManifest.xml")
                
                if (manifestFile.exists()) {
                    val manifestContent = manifestFile.readText()
                    val packageMatch = Regex("package=\"([^\"]+)\"").find(manifestContent)
                    if (packageMatch != null) {
                        namespace = packageMatch.groupValues[1]
                    }
                }
                
                // Fallback namespace if not found in manifest
                if (namespace == null) {
                    namespace = "fr.g123k.deviceapps"
                }
                
                // Configure android block
                project.extensions.configure<com.android.build.gradle.BaseExtension>("android") {
                    this.namespace = namespace
                    println("✅ Set namespace for ${project.name}: $namespace")
                }
            } catch (e: Exception) {
                println("⚠️ Could not set namespace for ${project.name}: ${e.message}")
                // Try alternative approach - set in gradle.properties
                try {
                    val fallbackNamespace = namespace ?: "fr.g123k.deviceapps"
                    val gradleProps = project.file("gradle.properties")
                    if (!gradleProps.exists()) {
                        gradleProps.createNewFile()
                    }
                    val props = java.util.Properties()
                    props.load(gradleProps.inputStream())
                    props.setProperty("android.namespace", fallbackNamespace)
                    props.store(gradleProps.outputStream(), null)
                    println("✅ Set namespace in gradle.properties for ${project.name}: $fallbackNamespace")
                } catch (e2: Exception) {
                    println("⚠️ Could not set namespace via gradle.properties: ${e2.message}")
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
