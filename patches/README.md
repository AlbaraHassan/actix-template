# Muslinx — musl Compatibility Patches

These patches fix compilation issues when building packages against musl libc
instead of glibc. Common issues addressed:

## Missing Functions/Headers in musl

| Function/Header | glibc | musl | Fix |
|----------------|-------|------|-----|
| `strtod_l()` | Yes | No | Use `strtod()` fallback |
| `locale_t` / `xlocale.h` | Yes | `locale.h` only | Include `locale.h` |
| `error.h` / `error()` | Yes | No | Use `fprintf(stderr, ...)` |
| `execinfo.h` / `backtrace()` | Yes | No | Use libunwind or disable |
| `sys/cdefs.h` | Yes | No | Create stub |
| `wordexp()` | Yes | No | Use alternative or disable |
| `rpc/rpc.h` | Yes | No | Build libtirpc |

## Detection Pattern

To detect musl at compile time (musl doesn't define `__MUSL__`):

```c
#if defined(__linux__) && !defined(__GLIBC__)
// Running on musl (or another non-glibc libc)
#endif
```

## Applying Patches

Patches are applied automatically by `scripts/helpers/apply-patches.sh`.
To apply manually:

```bash
cd /path/to/package-source
patch -p1 < /path/to/patches/package-musl.patch
```
