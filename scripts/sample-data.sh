#!/bin/bash
set -euo pipefail

sample_project_root="$(cd "$(dirname "$0")/.." && pwd)"
sample_command="${1:-validate}"

case "$sample_command" in
  validate)
    if [ "$#" -gt 1 ]; then
      echo "Usage: $0 validate" >&2
      exit 2
    fi
    ;;
  export-statement)
    if [ "$#" -gt 2 ]; then
      echo "Usage: $0 export-statement [outputPath]" >&2
      exit 2
    fi
    ;;
  -h|--help|help)
    echo "Usage: $0 validate"
    echo "       $0 export-statement [outputPath]"
    echo "Default export: $sample_project_root/build/Sample/statement.csv"
    exit 0
    ;;
  *)
    echo "Unknown command: $sample_command. Use validate or export-statement." >&2
    exit 2
    ;;
esac

sample_tool_directory="$sample_project_root/build/SampleTools"
mkdir -p "$sample_tool_directory"

# Compile the same models and validator used by the iOS app.
xcrun swiftc -parse-as-library \
  "$sample_project_root/WealthHub/Models.swift" \
  "$sample_project_root/WealthHub/SampleData.swift" \
  "$sample_project_root/scripts/sample-data.swift" \
  -o "$sample_tool_directory/sample-data"

if [ "$sample_command" = "export-statement" ]; then
  sample_output="${2:-$sample_project_root/build/Sample/statement.csv}"
  exec "$sample_tool_directory/sample-data" export-statement "$sample_project_root/Sample" "$sample_output"
else
  exec "$sample_tool_directory/sample-data" validate "$sample_project_root/Sample"
fi
