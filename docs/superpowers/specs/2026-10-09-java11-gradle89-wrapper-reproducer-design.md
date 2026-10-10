# Java 11 and Gradle 8.9 Wrapper Reproducer Design

## Purpose

Build a small standalone repository that reproduces a customer-reported Gradle wrapper propagation problem.

The repository must show whether endorctl uses `backend-jvm/gradlew` for manifests inside a wrapperless composite build. It must not depend on customer source code, private packages, or private credentials.

## Reproduction target

The fixture models the failing `backend-jvm` scan:

- The scan path is the Git repository root.
- The Gradle build is below that root in `backend-jvm/`.
- `backend-jvm/gradlew` uses Gradle 8.9.
- The build runs on Java 11.
- `backend-jvm/settings.gradle.kts` includes a wrapperless composite build.
- The selected canary contains six `build.gradle.kts` manifests.
- The scan includes `backend-jvm/gradlew` and the canary subtree.

The affected endorctl behavior runs selected manifests with bare `gradle` instead of `backend-jvm/gradlew`.

## Repository layout

```text
java-gradle-scan/
├── README.md
├── .gitignore
├── scripts/
│   ├── run-reproducer.sh
│   └── sentinel-bin/
│       └── gradle
└── backend-jvm/
    ├── build.gradle.kts
    ├── settings.gradle.kts
    ├── gradle.properties
    ├── gradlew
    ├── gradlew.bat
    ├── gradle/wrapper/
    │   ├── gradle-wrapper.jar
    │   └── gradle-wrapper.properties
    └── domains/ally-management/systems/ally-core/
        ├── build.gradle.kts
        ├── settings.gradle.kts
        ├── domain/
        │   ├── build.gradle.kts
        │   └── src/main/java/example/allycore/domain/DomainService.java
        ├── adapters/
        │   ├── build.gradle.kts
        │   └── src/main/java/example/allycore/adapters/DomainAdapter.java
        ├── components/
        │   ├── build.gradle.kts
        │   └── src/main/java/example/allycore/components/AllyCoreApplication.java
        └── libraries/ally-core-api/
            ├── build.gradle.kts
            └── ally-core-api/
                ├── build.gradle.kts
                └── src/main/java/example/allycore/api/AllyCoreApi.java
```

## Gradle topology

`backend-jvm/settings.gradle.kts` includes `domains/ally-management/systems/ally-core` with `includeBuild`.

The included build has no `gradlew` file. Its `settings.gradle.kts` declares these projects:

- `:domain`
- `:adapters`
- `:components`
- `:libraries:ally-core-api`
- `:libraries:ally-core-api:ally-core-api`

Together with the included build root, this gives six manifests. This matches the customer-reported `backend-jvm` canary count.

The projects use explicit Maven groups but leave the Gradle version unset. Gradle therefore uses `unspecified`, matching the customer package coordinates.

The fixture has no third-party dependencies. Project dependencies are sufficient to test package discovery and wrapper selection.

## Build behavior

The outer build defines `buildAll`. This task delegates to the included build's `build` task.

The supported build command is:

```bash
./backend-jvm/gradlew -p backend-jvm buildAll
```

The README requires Java 11 and verifies:

```bash
java --version
./backend-jvm/gradlew -p backend-jvm --version
```

The expected Gradle version is 8.9.

## Deterministic bare-Gradle signal

`scripts/sentinel-bin/gradle` is an executable script. It prints:

```text
BARE_GRADLE_SENTINEL_INVOKED
```

It then exits with code 86.

`scripts/run-reproducer.sh` prepends this directory to `PATH` before it starts endorctl.

This removes the need to install global Gradle 9.4.1. The signal distinguishes the two behaviors:

- Correct: endorctl uses `backend-jvm/gradlew`. The sentinel does not run.
- Affected: endorctl uses bare `gradle`. The sentinel marker appears in the scan log.

## Endor scan

The script requires the caller to set:

- `ENDOR_NAMESPACE`
- `ENDOR_API`
- `JAVA_HOME`

It does not contain a tenant, token, or API default.

The script builds first, keeps the outputs, and then runs:

```bash
endorctl scan \
  --namespace "$ENDOR_NAMESPACE" \
  --api "$ENDOR_API" \
  --path "$REPO_ROOT" \
  --dependencies \
  --languages=java \
  --include-path='backend-jvm/gradlew' \
  --include-path='backend-jvm/domains/ally-management/systems/ally-core/**' \
  --detached-ref-name='java11-gradle89-wrapper-reproducer' \
  --tags='java11,gradle89,wrapper-reproducer' \
  --verbose
```

The script enables:

```text
ENDOR_LOG_LEVEL=debug
ENDOR_SCAN_GRADLE_PRINT_DEBUG=true
```

It writes the complete output to `java11-gradle89-wrapper-reproducer.log`.

## Expected affected result

On an affected endorctl version:

- Root project discovery uses `backend-jvm/gradlew`.
- One or more selected manifest commands use bare `gradle`.
- The log contains `BARE_GRADLE_SENTINEL_INVOKED`.
- Dependency resolution fails before package creation.
- The scan can report zero packages and an incorrect zero-failure summary.

## Expected fixed result

On a fixed endorctl version:

- Every selected manifest uses `backend-jvm/gradlew`.
- The sentinel marker is absent.
- Source packages have nonempty Maven coordinates.
- Dependency analyses complete for the selected packages.
- A real dependency failure increments the scan failure count.

## Local validation

Before any endorctl scan:

1. Run `./scripts/verify-fixture.sh` to verify the structure and sentinel contract.
2. Confirm the wrapper reports Gradle 8.9.
3. Confirm the wrapper uses Java 11.
4. Run `buildAll`.
5. Run `./scripts/verify-fixture.sh --built` to confirm JAR or class output exists.

The implementation must not run endorctl automatically during local validation. An endorctl scan writes data to the namespace selected by the user.

## Out of scope

- Customer source code or proprietary build plugins.
- Mandrel Java 25.
- The competing nested-wrapper coordinate-loss case.
- A fix to endorctl.
- CI automation.
- Publishing artifacts to Maven Local.
- Third-party package vulnerabilities.

## Success criteria

The repository is ready when:

1. A clean clone builds with Java 11 and Gradle wrapper 8.9.
2. The included build has six Gradle manifests and no wrapper.
3. The build creates JAR or class output for the canary.
4. The sentinel reliably identifies a bare `gradle` invocation.
5. The README contains exact build, scan, validation, and cleanup commands.
6. No credential, tenant, customer source, or private dependency is committed.

Built by endor-lmoreno's AI harness (harness v1.7.1165-180-ga00128d5c6-dirty - gpt-5.6-sol - default)
