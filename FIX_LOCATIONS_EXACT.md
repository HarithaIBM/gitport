# Exact Fix Locations - merge-file and diff --output

## Fix 1: git merge-file

### File: `git/builtin/merge-file.c`
### Function: `cmd_merge_file()`
### Lines: ~85-96

### Current Code (lines 85-96):
```c
} else {
    const char *filename = argv[0];
    char *fpath = prefix_filename(prefix, argv[0]);
    FILE *f = to_stdout ? stdout : fopen(fpath, "wb");

    if (!f)
        ret = error_errno("Could not open %s for writing",
                  filename);
    else if (result.size &&
         fwrite(result.ptr, result.size, 1, f) != 1)
        ret = error_errno("Could not write to %s", filename);
    else if (fclose(f))
        ret = error_errno("Could not close %s", filename);
    free(fpath);
}
```

### Fixed Code:
```c
} else {
    const char *filename = argv[0];
    char *fpath = prefix_filename(prefix, argv[0]);
    FILE *f = to_stdout ? stdout : fopen(fpath, "wb");

    if (!f)
        ret = error_errno("Could not open %s for writing",
                  filename);
    else {
#ifdef __MVS__
        if (f != stdout) {
            int fd = fileno(f);
            if (fd >= 0) {
                __setfdbinary(fd);
                __disableautocvt(fd);
            }
        }
#endif
        if (result.size &&
            fwrite(result.ptr, result.size, 1, f) != 1)
            ret = error_errno("Could not write to %s", filename);

#ifdef __MVS__
        if (f != stdout && ret == 0) {
            int fd = fileno(f);
            if (fd >= 0) {
                /* Tag file according to .gitattributes */
                struct index_state *istate = the_repository->index;
                tag_file_as_working_tree_encoding(istate, argv[0], fd, 1);
            }
        }
#endif
        if (fclose(f))
            ret = error_errno("Could not close %s", filename);
    }
    free(fpath);
}
```

### What Changed:
1. Added `#ifdef __MVS__` blocks
2. After `fopen()`: Get fd, disable auto-conversion (skip if stdout)
3. After `fwrite()`: Tag the file with `tag_file_as_working_tree_encoding()`
4. Wrapped the `else if` chain in a proper `else { }` block

### Dependencies:
Need to add at top of file:
```c
#include "convert.h"
```

---

## Fix 2: git diff --output

### File: `git/diff.c`
### Two locations to modify:

#### Location 1: After opening file (~line 5846-5852)
**Function:** `diff_opt_output()`

### Current Code:
```c
static int diff_opt_output(const struct option *opt,
               const char *arg, int unset)
{
    struct diff_options *options = opt->value;
    char *path;

    BUG_ON_OPT_NEG(unset);
    path = prefix_filename(ctx->prefix, arg);
    options->file = xfopen(path, "w");
    options->close_file = 1;
    if (options->use_color != GIT_COLOR_ALWAYS)
        options->use_color = GIT_COLOR_NEVER;
    free(path);
    return 0;
}
```

### Fixed Code:
```c
static int diff_opt_output(const struct option *opt,
               const char *arg, int unset)
{
    struct diff_options *options = opt->value;
    char *path;

    BUG_ON_OPT_NEG(unset);
    path = prefix_filename(ctx->prefix, arg);
    options->file = xfopen(path, "w");
    options->close_file = 1;
    
#ifdef __MVS__
    if (options->file) {
        int fd = fileno(options->file);
        if (fd >= 0) {
            __setfdbinary(fd);
            __disableautocvt(fd);
        }
    }
    /* Save path for later tagging */
    options->output_path = xstrdup(arg);
#endif
    
    if (options->use_color != GIT_COLOR_ALWAYS)
        options->use_color = GIT_COLOR_NEVER;
    free(path);
    return 0;
}
```

#### Location 2: Before closing file (~line 7185)
**Function:** `diff_free_file()`

### Current Code:
```c
static void diff_free_file(struct diff_options *options)
{
    if (options->close_file && options->file) {
        fclose(options->file);
        options->file = NULL;
    }
}
```

### Fixed Code:
```c
static void diff_free_file(struct diff_options *options)
{
    if (options->close_file && options->file) {
#ifdef __MVS__
        /* Tag file before closing */
        if (options->output_path) {
            int fd = fileno(options->file);
            if (fd >= 0) {
                struct index_state *istate = the_repository->index;
                tag_file_as_working_tree_encoding(istate, 
                                                 options->output_path, 
                                                 fd, 1);
            }
            free(options->output_path);
            options->output_path = NULL;
        }
#endif
        fclose(options->file);
        options->file = NULL;
    }
}
```

#### Location 3: Add field to struct diff_options
**File:** `git/diff.h`
**Struct:** `struct diff_options` (~line 370)

Add:
```c
#ifdef __MVS__
    char *output_path;  /* For z/OS file tagging */
#endif
```

### Dependencies:
Need to add at top of `diff.c`:
```c
#include "convert.h"
```

---

## Summary of Changes

### builtin/merge-file.c:
- Add `#include "convert.h"`
- Modify `cmd_merge_file()` function
- Add z/OS tagging after `fwrite()`, before `fclose()`
- Lines affected: ~85-96

### diff.c:
- Add `#include "convert.h"`
- Modify `diff_opt_output()` to disable auto-conversion and save path
- Modify `diff_free_file()` to tag before closing
- Lines affected: ~5846-5852, ~7185

### diff.h:
- Add `output_path` field to `struct diff_options`
- Line affected: ~370

---

## Why These Locations?

### merge-file:
- File is opened, written, and closed in one function
- Simple to add tagging right before `fclose()`
- Single location, easy fix

### diff --output:
- File is opened in `diff_opt_output()`
- File is written to throughout diff processing
- File is closed in `diff_free_file()`
- Need to:
  1. Disable auto-conversion when opening
  2. Save path for later
  3. Tag when closing (after all writes done)

---

## Testing Commands

### Test merge-file:
```bash
cd /tmp && rm -rf test-mf && mkdir test-mf && cd test-mf
git init && git config core.ignorefiletags false
echo "*.txt zos-working-tree-encoding=IBM-1047" > .gitattributes
echo "base" > base.txt
echo "ours" > ours.txt  
echo "theirs" > theirs.txt
git merge-file ours.txt base.txt theirs.txt
chtag -p ours.txt  # Should show IBM-1047
```

### Test diff --output:
```bash
cd /tmp && rm -rf test-diff && mkdir test-diff && cd test-diff
git init && git config core.ignorefiletags false
echo "*.diff zos-working-tree-encoding=IBM-1047" > .gitattributes
echo "v1" > f.txt && git add f.txt && git commit -m "v1"
echo "v2" > f.txt && git add f.txt && git commit -m "v2"
git diff HEAD~1 HEAD --output=out.diff
chtag -p out.diff  # Should show IBM-1047
```

