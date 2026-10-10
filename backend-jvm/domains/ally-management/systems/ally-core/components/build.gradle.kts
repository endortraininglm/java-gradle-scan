plugins {
    application
}

group = "com.example.system.ally-core"

java {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
}

application {
    mainClass.set("example.allycore.components.AllyCoreApplication")
}

dependencies {
    implementation(project(":domain"))
    implementation(project(":adapters"))
    implementation(project(":libraries:ally-core-api:ally-core-api"))
}
