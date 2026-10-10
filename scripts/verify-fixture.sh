#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
backend_root="$repo_root/backend-jvm"
canary_root="$backend_root/domains/ally-management/systems/ally-core"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

validate_build=false
case "$#" in
  0) ;;
  1)
    [[ "$1" == "--built" ]] || {
      printf 'Usage: %s [--built]\n' "$0" >&2
      exit 2
    }
    validate_build=true
    ;;
  *)
    printf 'Usage: %s [--built]\n' "$0" >&2
    exit 2
    ;;
esac

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

set +e
sentinel_output="$("$repo_root/scripts/sentinel-bin/gradle" 2>&1)"
sentinel_exit=$?
set -e

[[ "$sentinel_exit" == "86" ]] || fail "bare Gradle sentinel exited $sentinel_exit, expected 86"
[[ "$sentinel_output" == "BARE_GRADLE_SENTINEL_INVOKED" ]] || fail "bare Gradle sentinel output is incorrect"

bash -n "$repo_root/scripts/run-reproducer.sh"
bash -n "$repo_root/scripts/sentinel-bin/gradle"

if [[ "$validate_build" == true ]]; then
  artifact="$(
    find "$canary_root" -type f \
      \( -path '*/build/libs/*.jar' -o \( -path '*/build/classes/*' -name '*.class' \) \) \
      -print -quit
  )"
  [[ -n "$artifact" ]] || fail "expected a JAR or class artifact under the canary"
fi

printf 'Fixture contract passed.\n'

if [[ "$validate_build" == true ]]; then
  printf 'API-free build validation passed.\n'
fi
