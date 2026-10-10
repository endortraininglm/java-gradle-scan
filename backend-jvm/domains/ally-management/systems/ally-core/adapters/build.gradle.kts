plugins {
    `java-library`
}

group = "com.example.system.ally-core"

java {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
}

dependencies {
    implementation(project(":domain"))
    implementation(project(":libraries:ally-core-api:ally-core-api"))
}
