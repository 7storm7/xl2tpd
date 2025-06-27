# Changes to xl2tpd for Android Integration

This changelog documents the modifications applied to the upstream `xl2tpd` project (https://github.com/xelerance/xl2tpd)  

These changes were made to enable building and running `xl2tpd` as a standalone VPN client binary for AOSP-based systems.

---

## Commit 1: Android Build Compatibility

**File(s) modified**: `Makefile`

**Summary of changes**:
- Replaced default `CC` logic with conditional support for cross-compiling using Android NDK's Clang toolchain.
- Removed flags incompatible with Android (e.g., `-fstack-protector`).
- Introduced `ARCH_NAME` logic for `arm64`/`x86_64` output folder separation.
- Disabled installation rules for `/etc` and system service defaults (not applicable on Android).

---

## Commit 2: Foreground Mode & Logging for Android

**File(s) modified**: `xl2tpd.c`, `xl2tpd.h`, `control.c`

**Summary of changes**:
- Removed the call to `daemon()` to allow running in the foreground (required for Android native service model).
- Disabled syslog output; logging is now done to `stderr` or configurable file.
- Removed PID file generation (not used on Android).
- Improved error visibility during initialization (e.g., FIFO creation failure logs).
- Adjusted `SIGTERM` and exit handling to support Android service lifecycle.

---

## Commit 3: Script and Configuration Templates for Android

**Files added**:  
- `scripts/android/build_android_arm64_x86_64.sh`  
- `scripts/android/create_config_files.sh`  
- `scripts/android/README.md`  
- Sample configs under `scripts/android/configs/`

**Summary of changes**:
- Added helper script to cross-compile `xl2tpd` using Android NDK for both `arm64` and `x86_64`.
- Added script to generate Android-specific config files:
  - `xl2tpd.conf`
  - `options.l2tp.client`
  - `chap-secrets`
- All generated config paths are Android-compatible (e.g., `/data/local/tmp/`).
- Documented usage of scripts and build flow in `scripts/android/README.txt`.

---

## Build Instructions

```bash
./scripts/android/build_android_arm64_x86_64.sh \
  --ndk-path $HOME/Android/Sdk/ndk/27.2.12479018 \
  --api-level 29 \
  --source-dir $PWD
