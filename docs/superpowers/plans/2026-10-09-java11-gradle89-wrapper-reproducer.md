# Java 11 and Gradle 8.9 Wrapper Reproducer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone Java 11 and Gradle 8.9 repository that deterministically detects when endorctl uses bare `gradle` instead of the included repository wrapper.

**Architecture:** The Git repository root is not a Gradle root. `backend-jvm/` owns the only Gradle 8.9 wrapper and includes a wrapperless `ally-core` composite build with six manifests. A sentinel executable named `gradle` fails with a unique marker, so an affected endorctl run proves that it bypassed `backend-jvm/gradlew`.

**Tech Stack:** Java 11, Gradle 8.9, Kotlin Gradle DSL, Bash, endorctl

**Spec:** `docs/superpowers/specs/2026-10-09-java11-gradle89-wrapper-reproducer-design.md`

## Global Constraints

- Keep all work inside `/Users/lmoreno/git/endor-internal/java-gradle-scan`.
- Do not copy customer source code, build plugins, package names, credentials, tenant values, or private dependencies.
- Do not add third-party Java dependencies.
- Do not run endorctl during implementation or verification. The user runs the scan against an explicitly selected namespace.
- Generate and commit a standard Gradle 8.9 wrapper, including `gradle-wrapper.jar`.
- Use Java source and bytecode compatibility 11.
- Leave project versions unset so Gradle reports `unspecified`.
- Keep the composite build wrapperless.
- Preserve the exact six-manifest fixture shape from the design.
- Label the repository as a reproducer, not production sample code.

## Review Focus

- A nested wrapper must not appear under `ally-core`, or the fallback path is not reproduced.
- The outer wrapper must remain outside the canary subtree but inside the scan include list.
- The sentinel must enter `PATH` only after the prebuild completes.
- The scan script must fail before any API call when `ENDOR_NAMESPACE`, `ENDOR_API`, or `JAVA_HOME` is missing.
- Local validation must never invoke endorctl or write to a remote namespace.

---

### Task 1: Add the fixture contract test

**Files:**
- Create: `scripts/verify-fixture.sh`
- Create: `.gitignore`
- Test: `scripts/verify-fixture.sh`

**Interfaces:**
- Consumes: The repository layout defined by the design spec.
- Produces: `scripts/verify-fixture.sh`, a local, API-free contract check used by every later task.

- [ ] **Step 1: Write the failing fixture verification script**

Create `scripts/verify-fixture.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
backend_root="$repo_root/backend-jvm"
canary_root="$backend_root/domains/ally-management/systems/ally-core"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[[ -x "$backend_root/gradlew" ]] || fail "backend-jvm/gradlew is missing or not executable"
[[ -f "$backend_root/gradle/wrapper/gradle-wrapper.jar" ]] || fail "gradle-wrapper.jar is missing"
[[ -f "$backend_root/gradle/wrapper/gradle-wrapper.properties" ]] || fail "gradle-wrapper.properties is missing"
[[ -f "$backend_root/settings.gradle.kts" ]] || fail "outer settings.gradle.kts is missing"
[[ -f "$canary_root/settings.gradle.kts" ]] || fail "canary settings.gradle.kts is missing"

manifest_count="$(
  find "$canary_root" -name build.gradle.kts -type f -print | wc -l | tr -d ' '
)"
[[ "$manifest_count" == "6" ]] || fail "expected 6 canary manifests, found $manifest_count"

if find "$canary_root" \( -name gradlew -o -name gradlew.bat \) -type f -print -quit | read -r _; then
  fail "the composite canary must not contain a Gradle wrapper"
fi

case "$(cat "$backend_root/gradle/wrapper/gradle-wrapper.properties")" in
  *gradle-8.9-bin.zip*) ;;
  *) fail "wrapper does not select Gradle 8.9" ;;
esac

[[ -x "$repo_root/scripts/sentinel-bin/gradle" ]] || fail "bare Gradle sentinel is missing or not executable"

bash -n "$repo_root/scripts/run-reproducer.sh"
bash -n "$repo_root/scripts/sentinel-bin/gradle"

printf 'Fixture contract passed.\n'
```

Create `.gitignore`:

```gitignore
.DS_Store
.gradle/
**/.gradle/
**/build/
.tools/
*.log
```

Make the verification script executable.

- [ ] **Step 2: Run the contract test and verify RED**

Run:

```bash
./scripts/verify-fixture.sh
```

Expected: `FAIL: backend-jvm/gradlew is missing or not executable`.

- [ ] **Step 3: Verify script syntax**

Run:

```bash
bash -n scripts/verify-fixture.sh
```

Expected: exit code 0.

### Task 2: Create the Java 11 composite Gradle fixture

**Files:**
- Create: `backend-jvm/settings.gradle.kts`
- Create: `backend-jvm/build.gradle.kts`
- Create: `backend-jvm/gradle.properties`
- Create: `backend-jvm/gradlew`
- Create: `backend-jvm/gradlew.bat`
- Create: `backend-jvm/gradle/wrapper/gradle-wrapper.jar`
- Create: `backend-jvm/gradle/wrapper/gradle-wrapper.properties`
- Create: `backend-jvm/domains/ally-management/systems/ally-core/settings.gradle.kts`
- Create: `backend-jvm/domains/ally-management/systems/ally-core/build.gradle.kts`
- Create: `backend-jvm/domains/ally-management/systems/ally-core/domain/build.gradle.kts`
- Create: `backend-jvm/domains/ally-management/systems/ally-core/adapters/build.gradle.kts`
- Create: `backend-jvm/domains/ally-management/systems/ally-core/components/build.gradle.kts`
- Create: `backend-jvm/domains/ally-management/systems/ally-core/libraries/ally-core-api/build.gradle.kts`
- Create: `backend-jvm/domains/ally-management/systems/ally-core/libraries/ally-core-api/ally-core-api/build.gradle.kts`
- Create: `backend-jvm/domains/ally-management/systems/ally-core/domain/src/main/java/example/allycore/domain/DomainService.java`
- Create: `backend-jvm/domains/ally-management/systems/ally-core/adapters/src/main/java/example/allycore/adapters/DomainAdapter.java`
- Create: `backend-jvm/domains/ally-management/systems/ally-core/components/src/main/java/example/allycore/components/AllyCoreApplication.java`
- Create: `backend-jvm/domains/ally-management/systems/ally-core/libraries/ally-core-api/ally-core-api/src/main/java/example/allycore/api/AllyCoreApi.java`
- Test: `scripts/verify-fixture.sh`

**Interfaces:**
- Consumes: The six-manifest contract from Task 1.
- Produces: A Gradle 8.9 outer build and a wrapperless Java 11 composite build.

- [ ] **Step 1: Create the outer composite build**

Create `backend-jvm/settings.gradle.kts`:

```kotlin
rootProject.name = "backend-jvm"

includeBuild("domains/ally-management/systems/ally-core")
```

Create `backend-jvm/build.gradle.kts`:

```kotlin
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
```

Create `backend-jvm/gradle.properties`:

```properties
org.gradle.daemon=false
org.gradle.parallel=false
org.gradle.warning.mode=all
```

- [ ] **Step 2: Create the wrapperless included build**

Create `backend-jvm/domains/ally-management/systems/ally-core/settings.gradle.kts`:

```kotlin
rootProject.name = "ally-core"

include(":domain")
include(":adapters")
include(":components")
include(":libraries:ally-core-api")
include(":libraries:ally-core-api:ally-core-api")
```

Create `backend-jvm/domains/ally-management/systems/ally-core/build.gradle.kts`:

```kotlin
plugins {
    base
}

group = "com.example.system"

description = "Root project for the Java 11 ally-core reproducer."
```

Create `domain/build.gradle.kts`:

```kotlin
plugins {
    `java-library`
}

group = "com.example.system.ally-core"

java {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
}
```

Create `adapters/build.gradle.kts`:

```kotlin
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
```

Create `components/build.gradle.kts`:

```kotlin
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
```

Create `libraries/ally-core-api/build.gradle.kts`:

```kotlin
plugins {
    base
}

group = "com.example.library"

description = "Aggregate project for the ally-core API."
```

Create `libraries/ally-core-api/ally-core-api/build.gradle.kts`:

```kotlin
plugins {
    `java-library`
}

group = "com.example.library"

java {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
}
```

- [ ] **Step 3: Add minimal Java source**

Create `DomainService.java`:

```java
package example.allycore.domain;

public final class DomainService {
    public String greeting() {
        return "hello from Java 11";
    }
}
```

Create `AllyCoreApi.java`:

```java
package example.allycore.api;

public interface AllyCoreApi {
    String greeting();
}
```

Create `DomainAdapter.java`:

```java
package example.allycore.adapters;

import example.allycore.api.AllyCoreApi;
import example.allycore.domain.DomainService;

public final class DomainAdapter implements AllyCoreApi {
    private final DomainService domainService = new DomainService();

    @Override
    public String greeting() {
        return domainService.greeting();
    }
}
```

Create `AllyCoreApplication.java`:

```java
package example.allycore.components;

import example.allycore.adapters.DomainAdapter;

public final class AllyCoreApplication {
    private AllyCoreApplication() {}

    public static void main(String[] args) {
        System.out.println(new DomainAdapter().greeting());
    }
}
```

- [ ] **Step 4: Generate the Gradle 8.9 wrapper**

Use installed Gradle only to bootstrap the wrapper. Then regenerate it through Gradle 8.9:

```bash
gradle -p backend-jvm wrapper --gradle-version 8.9 --distribution-type bin
./backend-jvm/gradlew -p backend-jvm wrapper --gradle-version 8.9 --distribution-type bin
```

Expected:

- `backend-jvm/gradlew` exists and is executable.
- `backend-jvm/gradlew.bat` exists.
- `backend-jvm/gradle/wrapper/gradle-wrapper.jar` exists.
- `gradle-wrapper.properties` references `gradle-8.9-bin.zip`.
- The wrapper JAR SHA-256 is `498495120a03b9a6ab5d155f5de3c8f0d986a449153702fb80fc80e134484f17`.

- [ ] **Step 5: Run the fixture contract and verify it now fails only on the sentinel**

Run:

```bash
./scripts/verify-fixture.sh
```

Expected: `FAIL: bare Gradle sentinel is missing or not executable`.

### Task 3: Add the deterministic scan runner

**Files:**
- Create: `scripts/sentinel-bin/gradle`
- Create: `scripts/run-reproducer.sh`
- Test: `scripts/verify-fixture.sh`

**Interfaces:**
- Consumes: The built Gradle fixture from Task 2 and caller-provided `ENDOR_NAMESPACE`, `ENDOR_API`, and `JAVA_HOME`.
- Produces: A deterministic endorctl scan command and `java11-gradle89-wrapper-reproducer.log`.

- [ ] **Step 1: Add the bare Gradle sentinel**

Create `scripts/sentinel-bin/gradle`:

```bash
#!/usr/bin/env bash
set -euo pipefail

printf 'BARE_GRADLE_SENTINEL_INVOKED\n' >&2
exit 86
```

Make it executable.

- [ ] **Step 2: Add the guarded reproducer script**

Create `scripts/run-reproducer.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

require_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || {
    printf 'Required environment variable is not set: %s\n' "$name" >&2
    exit 2
  }
}

require_env ENDOR_NAMESPACE
require_env ENDOR_API
require_env JAVA_HOME

command -v endorctl >/dev/null 2>&1 || {
  printf 'endorctl is not available on PATH\n' >&2
  exit 2
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
wrapper="$repo_root/backend-jvm/gradlew"
canary_root="$repo_root/backend-jvm/domains/ally-management/systems/ally-core"
log_file="$repo_root/java11-gradle89-wrapper-reproducer.log"
repro_ref="${REPRO_REF:-java11-gradle89-wrapper-reproducer}"

java_output="$("$JAVA_HOME/bin/java" -version 2>&1)"
if [[ "$java_output" != *'"11.'* ]]; then
  printf 'JAVA_HOME must point to Java 11. Current output:\n%s\n' "$java_output" >&2
  exit 2
fi

export PATH="$JAVA_HOME/bin:$PATH"

"$wrapper" -p "$repo_root/backend-jvm" --version
"$wrapper" -p "$repo_root/backend-jvm" buildAll

artifact="$(
  find "$canary_root" -type f \
    \( -path '*/build/libs/*.jar' -o \( -path '*/build/classes/*' -name '*.class' \) \) \
    -print -quit
)"
[[ -n "$artifact" ]] || {
  printf 'The prebuild produced no JAR or class output under the canary.\n' >&2
  exit 2
}

export ENDOR_LOG_LEVEL=debug
export ENDOR_SCAN_GRADLE_PRINT_DEBUG=true
export PATH="$repo_root/scripts/sentinel-bin:$PATH"

printf 'Prebuilt artifact: %s\n' "$artifact"
printf 'Writing scan output to: %s\n' "$log_file"

endorctl scan \
  --namespace "$ENDOR_NAMESPACE" \
  --api "$ENDOR_API" \
  --path "$repo_root" \
  --dependencies \
  --languages=java \
  --include-path='backend-jvm/gradlew' \
  --include-path='backend-jvm/domains/ally-management/systems/ally-core/**' \
  --detached-ref-name="$repro_ref" \
  --tags='java11,gradle89,wrapper-reproducer' \
  --verbose \
  2>&1 | tee "$log_file"
```

Make it executable.

- [ ] **Step 3: Run the fixture contract and verify GREEN**

Run:

```bash
./scripts/verify-fixture.sh
```

Expected: `Fixture contract passed.`

- [ ] **Step 4: Verify the sentinel**

Run:

```bash
set +e
output="$(scripts/sentinel-bin/gradle 2>&1)"
status=$?
set -e
printf '%s\n' "$output"
test "$status" -eq 86
test "$output" = "BARE_GRADLE_SENTINEL_INVOKED"
```

Expected: both `test` commands pass.

- [ ] **Step 5: Verify guarded failure without remote writes**

Run:

```bash
env -u ENDOR_NAMESPACE -u ENDOR_API -u JAVA_HOME ./scripts/run-reproducer.sh
```

Expected: exit code 2 with `Required environment variable is not set: ENDOR_NAMESPACE`. The script must exit before it invokes endorctl.

### Task 4: Validate Java 11 and document repository use

**Files:**
- Modify: `README.md`
- Test: `scripts/verify-fixture.sh`

**Interfaces:**
- Consumes: The complete fixture and scripts from Tasks 1 through 3.
- Produces: Copy-ready setup, build, scan, interpretation, and cleanup instructions.

- [ ] **Step 1: Acquire a temporary Java 11 runtime for local verification**

Do not install a system-wide JDK. If Java 11 is not already available, download a temporary macOS arm64 Corretto archive outside the repository:

```bash
tmp_java="$(mktemp -d)"
curl -fsSL \
  https://corretto.aws/downloads/latest/amazon-corretto-11-aarch64-macos-jdk.tar.gz \
  -o "$tmp_java/corretto11.tar.gz"
tar -xzf "$tmp_java/corretto11.tar.gz" -C "$tmp_java"
export JAVA_HOME="$(find "$tmp_java" -type d -path '*/Contents/Home' -print -quit)"
export PATH="$JAVA_HOME/bin:$PATH"
java -version
```

Expected: Java reports major version 11.

- [ ] **Step 2: Build with Java 11 and Gradle 8.9**

Run:

```bash
./backend-jvm/gradlew -p backend-jvm --version
./backend-jvm/gradlew -p backend-jvm clean buildAll
```

Expected:

- Gradle reports 8.9.
- Launcher JVM reports Java 11.
- `BUILD SUCCESSFUL`.

- [ ] **Step 3: Confirm build output and bytecode level**

Run:

```bash
find backend-jvm/domains/ally-management/systems/ally-core \
  -type f \
  \( -path '*/build/libs/*.jar' -o \( -path '*/build/classes/*' -name '*.class' \) \) \
  -print

javap -verbose \
  backend-jvm/domains/ally-management/systems/ally-core/domain/build/classes/java/main/example/allycore/domain/DomainService.class \
  | rg 'major version: 55'
```

Expected:

- JAR and class files are listed.
- `javap` reports Java 11 class-file major version 55.

- [ ] **Step 4: Write the README**

Replace `README.md` with:

```markdown
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
```

- [ ] **Step 5: Run all local gates**

Run:

```bash
./scripts/verify-fixture.sh
bash -n scripts/verify-fixture.sh
bash -n scripts/run-reproducer.sh
bash -n scripts/sentinel-bin/gradle
./backend-jvm/gradlew -p backend-jvm clean buildAll
./scripts/verify-fixture.sh --built
git status --short
```

Expected:

- All scripts pass syntax checks.
- The fixture contract passes.
- The Gradle build passes on Java 11.
- `git status` shows only intended source, wrapper, script, documentation, spec, and plan files.
- No `.gradle`, `build`, `.tools`, log, credential, or token file is tracked.

- [ ] **Step 6: Remove temporary verification tools**

If Task 4 downloaded a temporary JDK:

```bash
rm -rf "$tmp_java"
```

Expected: the temporary JDK is removed and no JDK files exist in the repository.

## Execution handoff

Use one `code-writer` agent to implement all tasks because the wrapper, Gradle topology, scripts, and README must stay consistent. After implementation, use one fresh correctness reviewer focused on accidental external writes, wrapper placement, sentinel ordering, and fixture fidelity.
