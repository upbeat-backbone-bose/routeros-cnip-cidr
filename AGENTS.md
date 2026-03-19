# AGENTS.md - RouterOS CN IP List Generator

## Project Overview

This is a Shell script project that generates RouterOS scripts for importing Chinese IP CIDR lists (IPv4/IPv6) into MikroTik RouterOS.

## Project Structure

```
.
├── generator.bash           # Main script: downloads IP data, validates, generates .rsc
├── dist/
│   └── cn_ip_cidr.rsc      # Generated RouterOS script output
└── .github/
    └── workflows/
        └── cnip-cidr-gen.yml  # GitHub Actions: auto-generates every 15 days
```

## Build/Lint/Test Commands

### Run Generator
```bash
bash generator.bash
```

### Shell Linting (if shellcheck installed)
```bash
shellcheck generator.bash
```

### Syntax Check
```bash
bash -n generator.bash  # Check syntax without executing
```

### Manual Import Test (RouterOS simulation)
```bash
# Preview generated script structure
head -50 dist/cn_ip_cidr.rsc
tail -20 dist/cn_ip_cidr.rsc

# Count IP entries
grep -c "add address=" dist/cn_ip_cidr.rsc
```

## Code Style Guidelines

### Shell Script (generator.bash)

#### General
- Use `#!/bin/bash` shebang
- Add `set -euo pipefail` for strict error handling
- Use variables with descriptive names
- Quote variables to prevent word splitting and globbing
- Use `$(command)` for command substitution (not backticks)

#### Variables
```bash
# Good
WORK_DIR=$(cd $(dirname $0); pwd)
TMP_CIDR_V4="$WORK_DIR/tmp/all_cn.txt"

# Avoid
WORK_DIR=`cd $(dirname $0); pwd`
TMP="$WORK_DIR/tmp/all_cn.txt"
```

#### Conditionals
```bash
# Good
if [ -z "$var" ]; then
    echo "empty"
fi

# Use [[ ]] for pattern matching
if [[ "$line" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
    echo "valid"
fi
```

#### Functions
```bash
validate_ip_cidr() {
    local file=$1
    local valid_count=0
    local invalid_count=0
    # ...
}
```

#### Error Handling
```bash
# With exit code
curl --max-time 60 -sL "$URL" -o "$FILE" || { echo "Failed"; exit 1; }

# Or use set -e (already enabled via pipefail)
```

#### Heredocs
```bash
# Use 'EOF' (not EOF) to prevent variable expansion
cat > file << 'EOF'
/log info "message..."
EOF
```

### GitHub Actions Workflows

#### Action Version Pinning
```yaml
# Good - pinned version
uses: actions/checkout@v6.0.0

# Avoid - floating version
uses: actions/checkout@v6
```

#### YAML Formatting
- Use 2-space indentation
- Quote strings that contain special characters
- Use `run: |-` for multi-line scripts

#### CI Best Practices
- Always check if there are changes before committing
- Use `--quiet` flag for `git diff` when checking for changes
- Set appropriate timeouts for network operations

## Dependencies

This project fetches IP data from external GitHub repositories:
- https://raw.githubusercontent.com/soffchen/GeoIP2-CN/release/CN-ip-cidr.txt (IPv4)
- https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/china6.txt (IPv6)

## Git Workflow

1. Create feature branch: `git checkout -b YYMMDD-(feat|fix|chore)-description`
2. Make changes and test locally
3. Commit with conventional format: `type: description`
4. Push and create PR
5. Merge to master via PR

## Notes

- The generated `dist/cn_ip_cidr.rsc` file is auto-generated and should not be manually edited
- The `tmp/` directory is git-ignored and contains temporary download files
- RouterOS 7+ is required for IPv6 support
- The script uses `on-error={}` to tolerate individual IP import failures
