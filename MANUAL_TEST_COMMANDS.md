# Manual Test Commands - Demonstrate Tagging Issues

## Setup

```bash
# Create test directory
cd /tmp
rm -rf tag-test
mkdir tag-test && cd tag-test

# Initialize repo
git init
git config user.name "Test"
git config user.email "test@test.com"
git config core.ignorefiletags false

# Create .gitattributes
echo "*.txt zos-working-tree-encoding=IBM-1047" > .gitattributes
git add .gitattributes
git commit -m "Add gitattributes"
```

---

## Test 1: git merge-file

### Command:
```bash
# Create three versions of a file
echo "base content" > base.txt
echo "our content" > ours.txt
echo "their content" > theirs.txt

# Merge them
git merge-file ours.txt base.txt theirs.txt

# Check tag
chtag -p ours.txt
```

### Expected:
```
t IBM-1047   T=on  ours.txt
```

### Actual (BUGGY):
```
t ISO8859-1  T=on  ours.txt
```

### Why it's wrong:
- File should be tagged as IBM-1047 per .gitattributes
- But merge-file writes with fopen/fwrite without tagging

---

## Test 2: git diff --output

### Command:
```bash
# Create two versions
echo "version 1" > file.txt
git add file.txt
git commit -m "Version 1"

echo "version 2" > file.txt
git add file.txt
git commit -m "Version 2"

# Create diff with --output
git diff HEAD~1 HEAD --output=my.diff

# Check tag
chtag -p my.diff
```

### Expected:
```
t IBM-1047   T=on  my.diff
```

### Actual (BUGGY):
```
t ISO8859-1  T=on  my.diff
```

### Why it's wrong:
- .gitattributes says *.txt (and *.diff if specified) should be IBM-1047
- But diff --output writes without checking attributes/tagging

---

## Test 3: git apply

### Command:
```bash
# Create a file
echo "original line 1" > test.txt
echo "original line 2" >> test.txt
git add test.txt
git commit -m "Original"

# Make a change and create patch
echo "modified line 1" > test.txt
echo "original line 2" >> test.txt
git diff > /tmp/test.patch

# Reset and apply
git checkout test.txt

# Apply patch
git apply /tmp/test.patch

# Check tag
chtag -p test.txt
```

### Expected:
```
t IBM-1047   T=on  test.txt
```

### Result:
- Should work (uses apply mechanism which has tagging)
- If fails, might be test issue or need investigation

---

## Test 4: git rebase (non-interactive)

### Command:
```bash
# Create base
echo "base" > file.txt
git add file.txt
git commit -m "Base"

# Create branch
git checkout -b feature
echo "feature change" > file.txt
git add file.txt
git commit -m "Feature"

# Go back and make another commit
git checkout master
echo "another file" > other.txt
git add other.txt
git commit -m "Other"

# Rebase (non-interactive, no editor)
git checkout feature
git rebase master

# Check tag
chtag -p file.txt
```

### Expected:
```
t IBM-1047   T=on  file.txt
```

### Result:
- Should work (uses checkout mechanism which has tagging)
- Previous test hung because of interactive mode

