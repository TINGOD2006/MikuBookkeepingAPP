// ===== 这是你缺少的部分 =====
buildscript {
    extra["kotlin_version"] = "1.9.0"  // 或使用最新版本
    
    repositories {
        google()
        mavenCentral()
    }
    
    dependencies {
        // 关键：声明 Android Gradle 插件的 classpath
        classpath("com.android.tools.build:gradle:7.4.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:${extra["kotlin_version"]}")
    }
}
// ===========================

// ===== 以下是你的现有代码 =====
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}