# Conversion Error Handling - Design Decision Needed

## Issue Summary

When `convert_to_working_tree()` returns `< 0` (encoding conversion error), the current patches fall back to using unconverted data instead of failing the operation.

Copilot flags this as "High" priority in 5 files:
1. `apply.c.patch` - try_create_file()
2. `builtin/cat-file.c.patch`
3. `diff.c.patch`
4. `entry.c.patch` - write_entry()
5. `parallel-checkout.c.patch`

Plus one unrelated issue:
6. `imap-send.c.patch` - ASN1_STRING strlen() safety

## Current Behavior

```c
int ret = convert_to_working_tree(...);
if (ret > 0) {
    // Use converted data
}
// Falls through - uses original data even if ret < 0
```

##Human: I mean issues. Not whether mandatory or not. I wanted to know whether fixes are there or not.
