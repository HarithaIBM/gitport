# Git SSH Push/Pull Encoding Issue on z/OS

## Problem

```
$ git push
fatal: protocol error: bad line length character: ���
```

**Root Cause:** z/OS auto-conversion (`_BPXK_AUTOCVT=ON`) is corrupting Git's binary protocol over SSH.

---

## Solution

### Quick Fix (Immediate)

Set these environment variables **before** running git push/pull/clone/fetch:

```bash
export _BPXK_AUTOCVT=OFF
export _BPX_SHAREAS=NO

# Now git operations will work
git push
git pull
git clone git@github.ibm.com:ihs-team/ihsbldtst.git
```

### Permanent Fix (Recommended)

Add to your `~/.profile` or `~/.bashrc`:

```bash
# Disable auto-conversion for Git
if command -v git >/dev/null 2>&1; then
    export _BPXK_AUTOCVT=OFF
    export _BPX_SHAREAS=NO
fi
```

Or create a Git wrapper script:

```bash
cat > ~/bin/git-wrapper.sh << 'SCRIPT'
#!/bin/sh
# Git wrapper to disable auto-conversion
export _BPXK_AUTOCVT=OFF
export _BPX_SHAREAS=NO
exec /path/to/git "$@"
SCRIPT

chmod +x ~/bin/git-wrapper.sh
alias git='~/bin/git-wrapper.sh'
```

---

## Why This Happens

Git's protocol uses **4-byte binary length prefixes** like:
```
00 4f 00 00  (binary: 79 bytes follows)
```

With `_BPXK_AUTOCVT=ON`, z/OS converts this to EBCDIC:
```
f0 f0 f4 c6  (EBCDIC "004F")
```

Git tries to parse this as a length and gets garbage like `���` or `pqr`.

---

## Verification

### Check Your Settings

```bash
echo "_BPXK_AUTOCVT=$_BPXK_AUTOCVT"
echo "_BPX_SHAREAS=$_BPX_SHAREAS"
echo "_CEE_RUNOPTS=$_CEE_RUNOPTS"
```

### Test Fix

```bash
# Before fix - fails
git ls-remote git@github.ibm.com:ihs-team/ihsbldtst.git
# fatal: protocol error: bad line length character: ���

# Apply fix
export _BPXK_AUTOCVT=OFF
export _BPX_SHAREAS=NO

# After fix - works
git ls-remote git@github.ibm.com:ihs-team/ihsbldtst.git
# Should show branches/tags
```

---

## Important Notes

### What About Local Operations?

Local Git operations (add, commit, log, show) work fine because they use **file I/O**, not SSH.

### What About _CEE_RUNOPTS?

You might think `_CEE_RUNOPTS='FILETAG(AUTOCVT,AUTOTAG)'` is the problem, but:
- This affects **stdio** redirection only
- SSH uses **binary pipes**, controlled by `_BPXK_AUTOCVT`

### Can I Leave AUTOCVT On?

**Not for Git SSH operations!** The binary protocol is incompatible with auto-conversion.

Options:
1. Turn off globally (safest for developers)
2. Use wrapper script (per-command)
3. Create shell function:
   ```bash
   git() {
       ( export _BPXK_AUTOCVT=OFF _BPX_SHAREAS=NO; command git "$@" )
   }
   ```

---

## Alternative: Use HTTPS Instead

If you can't disable auto-conversion:

```bash
# Change remote from SSH to HTTPS
git remote set-url origin https://github.ibm.com/ihs-team/ihsbldtst.git

# Use personal access token
git config --global credential.helper store
# Enter token when prompted
```

HTTPS is less affected by encoding issues (though still has some quirks).

---

## For System Administrators

If Git is installed system-wide, wrap it:

```bash
# /usr/local/bin/git
#!/bin/sh
export _BPXK_AUTOCVT=OFF
export _BPX_SHAREAS=NO
exec /path/to/real/git "$@"
```

Or document in `/etc/profile.d/git.sh`:
```bash
# Git requires binary mode for SSH
export _BPXK_AUTOCVT=OFF
export _BPX_SHAREAS=NO
```

---

## Testing the Fix

```bash
# 1. Test remote listing
git ls-remote git@github.ibm.com:ihs-team/ihsbldtst.git

# 2. Test fetch
git fetch origin

# 3. Test push (if you have local commits)
git push origin main

# 4. Test clone
cd /tmp
git clone git@github.ibm.com:ihs-team/ihsbldtst.git test-clone
```

All should work without "bad line length character" errors.

---

## Related Issues

This is **not** a Git bug - it's a z/OS environment issue. The same problem affects:
- Git over SSH (push/pull/fetch/clone)
- Git submodules over SSH
- Git LFS over SSH

But does **not** affect:
- Local operations (add, commit, log, diff, show)
- HTTPS operations (usually)
- File operations

---

## Summary

**Problem:** Auto-conversion corrupts binary SSH protocol  
**Fix:** `export _BPXK_AUTOCVT=OFF _BPX_SHAREAS=NO`  
**Where:** In `~/.profile` or wrapper script  
**Test:** `git ls-remote <ssh-url>` should work  

This is a **z/OS environment configuration issue**, not a Git code bug.

