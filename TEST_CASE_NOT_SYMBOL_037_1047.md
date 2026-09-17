# Test Case: NOT Symbol (¬) Encoding Issue - IBM-037 vs IBM-1047

## Issue Description

**User Report:**
> When trying to setup .gitattributes file to enable autoconversion to IBM-1047, I get errors:
> ```
> error: failed to encode 'file.plx' from UTF-8 to ibm-1047
> ```
> File contains ¬ symbol (0xb0 in the original file).
> After failed clone, file has IBM-1047 tag but contains UTF-8 data (gibberish in vim).

**Root Cause:**
- File was originally created/edited in IBM-037 encoding
- 0xb0 in IBM-037 = ¬ (NOT symbol)
- 0xb0 in IBM-1047 = ° (degree symbol)
- Different character mappings cause conversion confusion

---

## Prerequisites

- z/OS system with USS
- Git for z/OS installed
- Access to create test repositories
- vim or another text editor

---

## Test Case 1: Reproduce the Issue

### Step 1: Create Test Repository

```bash
# Create test directory
cd /tmp
mkdir git-not-test
cd git-not-test

# Initialize git repo
git init
git config user.name "Test User"
git config user.email "test@test.com"
git config core.ignorefiletags false
```

### Step 2: Create .gitattributes

```bash
# Set all .plx files to use IBM-1047
cat > .gitattributes << 'EOF'
*.plx zos-working-tree-encoding=IBM-1047
