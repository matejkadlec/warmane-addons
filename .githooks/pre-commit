#!/usr/bin/env bash
set -euo pipefail

staged_files="$(git diff --cached --name-only --diff-filter=ACMR)"
if [[ -z "$staged_files" ]]; then
    exit 0
fi

declare -A addon_dirs=()
while IFS= read -r file; do
    [[ "$file" == addons/*/* ]] || continue
    addon_dir="${file#addons/}"
    addon_dir="${addon_dir%%/*}"
    addon_dirs["$addon_dir"]=1
done <<< "$staged_files"

if [[ ${#addon_dirs[@]} -eq 0 ]]; then
    exit 0
fi

failures=0
messages=()

for addon_dir in "${!addon_dirs[@]}"; do
    if ! git diff --cached --name-only --diff-filter=ACMR -- "addons/$addon_dir/" | grep -q .; then
        continue
    fi

    toc_path="addons/$addon_dir/$addon_dir.toc"

    # Skip folders that are not single-addon roots with matching toc naming.
    if ! git cat-file -e ":$toc_path" 2>/dev/null; then
        continue
    fi

    new_version="$(git show ":$toc_path" | sed -n 's/^## Version:[[:space:]]*//p' | head -n1 | tr -d '\r')"
    if [[ -z "$new_version" ]]; then
        messages+=("[$addon_dir] Missing '## Version:' in staged $toc_path")
        failures=1
        continue
    fi

    old_version=""
    if git cat-file -e "HEAD:$toc_path" 2>/dev/null; then
        old_version="$(git show "HEAD:$toc_path" | sed -n 's/^## Version:[[:space:]]*//p' | head -n1 | tr -d '\r')"
    fi

    # Existing addon: require a version change if anything in addon folder is staged.
    if [[ -n "$old_version" && "$new_version" == "$old_version" ]]; then
        messages+=("[$addon_dir] TOC version unchanged ($new_version) while files in addons/$addon_dir/ are staged.")
        failures=1
    fi
done

if [[ $failures -ne 0 ]]; then
    echo "pre-commit: addon TOC version check failed."
    for msg in "${messages[@]}"; do
        echo "  - $msg"
    done
    echo "Bump '## Version:' in each affected .toc file, stage it, and commit again."
    exit 1
fi

exit 0
