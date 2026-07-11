// android/build.gradle.kts

buildscript {
    repositories {
        // 1. 阿里云镜像加速
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }

        
        google()
        mavenCentral()
    }
    dependencies {
        // 这里通常由 Flutter 自动管理，保持默认即可
    }
}

allprojects {
    repositories {
        // 2. 这里的镜像也非常重要，是下载第三方库的地方
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }
        
        google()
        mavenCentral()
    }
}

// 这里的配置是 Flutter 自动生成的编译路径管理
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}