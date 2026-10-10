plugins {
    base
}

val allyCore = gradle.includedBuild("ally-core")

tasks.register("buildAll") {
    group = "build"
    description = "Build every project in the ally-core composite."
    dependsOn(
        allyCore.task(":domain:build"),
        allyCore.task(":adapters:build"),
        allyCore.task(":components:build"),
        allyCore.task(":libraries:ally-core-api:build"),
        allyCore.task(":libraries:ally-core-api:ally-core-api:build"),
    )
}
