# Fix Locations for merge-file and diff --output

## 1. git merge-file (builtin/merge-file.c)

### Location to Fix:
**File:** `git/builtin/merge-file.c`
**Function:** `cmd_merge_file()`
**Lines:** Around 80-85

### Current Code:
```c
if (ret >= 0) {
    const char *filename = argv[0];
    char *fpath = prefix_filename(prefix, filename);
    FILE *f = fopen(fpath, "wb");

    if (!f)
        ret = error_errno("Could not open %s for writing",
                  filename);
    else if (write_in_full(fileno(f), result.ptr, result.size) < 0)
        ret = error_errno("Could not write to %s", filename);
    else if (fclose(f))
        ret = error_errno("Could not close %s", filename);
    free(fpath);
}
```

### What to Add:
After `fopen()` and before writing:
1. Get file descriptor with `fileno(f)`
2. Disable auto-conversion (`__setfdbinary`, `__disableautocvt`)
3. After writing, before `fclose()`: call `tag_file_as_working_tree_encoding()`

---

## 2. git diff --output (diff.c)

### Location to Fix:
**File:** `git/diff.c`
**Function:** `diff_opt_output()`
**Lines:** Around 5848

### Current Code:
```c
static int diff_opt_output(struct diff_options *options,
                           const char *arg, const char *unset)
{
    BUG_ON_OPT_NEG(unset);
    options->file = xfopen(arg, "w");
    options->close_file = 1;
    if (options->use_color != GIT_COLOR_ALWAYS)
        options->use_color = GIT_COLOR_NEVER;
    return 0;
}
```

### What to Add:
After `xfopen()`:
1. Get file descriptor with `fileno(options->file)`
2. Disable auto-conversion
3. Need to tag when file is closed (but where is it closed?)

### Problem:
The file is opened here but written to elsewhere and closed in `diff_free_file()`. 
Need to find where to add tagging - either:
- After open (tag the empty file)
- When closing (in `diff_free_file()`)

---

## Let me find the exact line numbers...

