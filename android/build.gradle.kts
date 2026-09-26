import org.gradle.kotlin.dsl.withGroovyBuilder

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

// بعض إضافات فلاتر (زي flutter_timezone) بتيجي بإعداد لغة جافا/كوتلن
// مختلف عن إعداد التطبيق نفسه، وده بيوقّع Gradle في تعارض بيوقف البناء.
// السطور دي بتوحّد الإعداد على كل الإضافات عشان البناء ينجح. لازم يتسجل
// قبل السطر اللي تحت اللي بيجبر Gradle يقيّم مشروع app بدري.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.withGroovyBuilder {
            "compileOptions" {
                setProperty("sourceCompatibility", JavaVersion.VERSION_17)
                setProperty("targetCompatibility", JavaVersion.VERSION_17)
            }
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
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
