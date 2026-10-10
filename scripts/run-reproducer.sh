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

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
wrapper="$repo_root/backend-jvm/gradlew"
canary_root="$repo_root/backend-jvm/domains/ally-management/systems/ally-core"
log_file="$repo_root/java11-gradle89-wrapper-reproducer.log"
repro_ref="${REPRO_REF:-java11-gradle89-wrapper-reproducer}"
java_bin="$JAVA_HOME/bin/java"

[[ -x "$java_bin" ]] || {
  printf 'JAVA_HOME does not contain an executable Java runtime: %s\n' "$java_bin" >&2
  exit 2
}

if ! java_output="$("$java_bin" -version 2>&1)"; then
  printf 'Unable to run Java from JAVA_HOME: %s\n%s\n' "$java_bin" "$java_output" >&2
  exit 2
fi

if [[ "$java_output" != *'"11.'* ]]; then
  printf 'JAVA_HOME must point to Java 11. Current output:\n%s\n' "$java_output" >&2
  exit 2
fi

command -v endorctl >/dev/null 2>&1 || {
  printf 'endorctl is not available on PATH\n' >&2
  exit 2
}

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
