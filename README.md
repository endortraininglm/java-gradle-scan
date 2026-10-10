# Java 11 and Gradle 8.9 wrapper reproducer

This repository reproduces an endorctl Gradle wrapper propagation issue with a Java 11 composite build.

The Git repository root is not a Gradle root. The only wrapper is `backend-jvm/gradlew`. The selected `ally-core` composite build has six manifests and no wrapper.

## Requirements

- Java 11
- endorctl
- Access to a test namespace

Do not use a customer or production namespace for experimentation.

## Verify the fixture

```bash
./scripts/verify-fixture.sh
```

This command verifies the repository structure and the exact sentinel output and exit code. It does not run endorctl.

## Build

```bash
test -x "${JAVA_HOME:?Set JAVA_HOME to a Java 11 installation}/bin/java"
export PATH="$JAVA_HOME/bin:$PATH"

java -version
./backend-jvm/gradlew -p backend-jvm --version
./backend-jvm/gradlew -p backend-jvm clean buildAll
./scripts/verify-fixture.sh --built
```

Java must report major version 11. The wrapper must report Gradle 8.9 and Java 11. The final command requires at least one JAR or class artifact and does not run endorctl.

## Run the reproducer

The scan creates data in the namespace that you select.

```bash
test -n "${ENDOR_NAMESPACE:?Set ENDOR_NAMESPACE to a test namespace}"
export ENDOR_API="https://api.endorlabs.com"
test -x "${JAVA_HOME:?Set JAVA_HOME to a Java 11 installation}/bin/java"

./scripts/run-reproducer.sh
```

Set `REPRO_REF` to use a different detached ref:

```bash
export REPRO_REF="java11-gradle89-wrapper-reproducer-2"
```

## Interpret the result

Affected behavior:

- The log contains `BARE_GRADLE_SENTINEL_INVOKED`.
- endorctl used bare `gradle` for a selected composite manifest.
- Dependency resolution stops before package creation.

Fixed behavior:

- The sentinel marker is absent.
- Every selected manifest uses `backend-jvm/gradlew`.
- Package coordinates are nonempty.
- Dependency analyses complete.

The complete scan output is written to:

```text
java11-gradle89-wrapper-reproducer.log
```

## Cleanup

```bash
find backend-jvm -type d -name .gradle -prune -exec rm -rf {} +
find backend-jvm -type d -name build -prune -exec rm -rf {} +
rm -f java11-gradle89-wrapper-reproducer.log
```