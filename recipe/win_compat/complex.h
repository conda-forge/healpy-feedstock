/*
 *  Minimal <complex.h> compatibility shim for Windows healpy builds.
 *
 *  Provides a small subset of the C99 <complex.h> interface sufficient for
 *  healpy/libsharp to compile where the standard header is unavailable.
 *
 *  Written specifically for the conda-forge healpy build, and intended
 *  for the autotools_clang_conda toolchain.
 *
 *  License: BSD-3-Clause
 */

#ifndef HEALPY_WIN_COMPLEX_H
#define HEALPY_WIN_COMPLEX_H

#ifndef __cplusplus
#ifndef complex
#define complex _Complex
#endif

#ifndef _Complex_I
#define _Complex_I (__extension__ 1.0fi)
#endif

#ifndef I
#define I _Complex_I
#endif

#ifndef creal
#define creal(x) __builtin_creal(x)
#endif
#ifndef cimag
#define cimag(x) __builtin_cimag(x)
#endif
#ifndef crealf
#define crealf(x) __builtin_crealf(x)
#endif
#ifndef cimagf
#define cimagf(x) __builtin_cimagf(x)
#endif
#ifndef creall
#define creall(x) __builtin_creall(x)
#endif
#ifndef cimagl
#define cimagl(x) __builtin_cimagl(x)
#endif
#ifndef conj
#define conj(x) __builtin_conj(x)
#endif
#ifndef conjf
#define conjf(x) __builtin_conjf(x)
#endif
#ifndef conjl
#define conjl(x) __builtin_conjl(x)
#endif
#endif

#endif
