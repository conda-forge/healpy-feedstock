#!/bin/bash
set -ex

pkg_config_libs() {
    local pkg="$1"
    local libs=""

    if command -v pkg-config >/dev/null 2>&1; then
        libs="$(pkg-config --libs "$pkg" 2>/dev/null || true)"
        libs="$(echo "${libs}" | sed 's/[[:space:]]-lm\>/ /g')"
    fi

    echo "${libs}"
}

config_aux_dir=""

for candidate in \
    "$BUILD_PREFIX/share/libtool/build-aux" \
    "$BUILD_PREFIX/Library/usr/share/libtool/build-aux" \
    "$BUILD_PREFIX/Library/usr/share/autoconf/build-aux"
do
    if [ -f "$candidate/config.guess" ] && [ -f "$candidate/config.sub" ]; then
        config_aux_dir="$candidate"
        break
    fi
done

if [ -z "${config_aux_dir}" ]; then
    echo "Could not locate config.guess/config.sub under BUILD_PREFIX=${BUILD_PREFIX}" >&2
    exit 1
fi

if [ "${target_platform}" = "win-64" ]; then
    recipe_dir_posix="$(cygpath -u "${RECIPE_DIR}")"
    build_prefix_posix="$(cygpath -u "${BUILD_PREFIX}")"
    prefix_posix="$(cygpath -u "${PREFIX}")"
    library_inc_posix="$(cygpath -u "${LIBRARY_INC}")"
    library_lib_posix="$(cygpath -u "${LIBRARY_LIB}")"

    # Normalize raw Windows -I/-L flags injected by activation so autotools and
    # libtool do not mangle them.
    CFLAGS="$(echo "${CFLAGS}" | sed -E 's@-I([A-Za-z]):@-I/\L\1/@g; s@\\@/@g')"
    CPPFLAGS="$(echo "${CPPFLAGS}" | sed -E 's@-I([A-Za-z]):@-I/\L\1/@g; s@\\@/@g')"
    LDFLAGS="$(echo "${LDFLAGS}" | sed -E 's@-L([A-Za-z]):@-L/\L\1/@g; s@\\@/@g')"

    export CFLAGS="-I${library_inc_posix} ${CFLAGS} -D_CRT_DECLARE_NONSTDC_NAMES=0 -Wno-implicit-function-declaration"
    export CPPFLAGS="-I${library_inc_posix} ${CPPFLAGS}"
    export LDFLAGS="-L${library_lib_posix} ${LDFLAGS}"

    # Provide small compatibility shims for missing headers/tools that
    # the upstream build system expects to exist on Unix-like systems.
    export PATH="${recipe_dir_posix}/win_compat:${PATH}"
    export CPPFLAGS="-I${recipe_dir_posix}/win_compat ${CPPFLAGS}"

    pkgconfig_paths="${prefix_posix}/Library/lib/pkgconfig:${prefix_posix}/lib/pkgconfig"
    if [ -n "${PKG_CONFIG_PATH:-}" ]; then
        pkgconfig_paths="${pkgconfig_paths}:${PKG_CONFIG_PATH}"
    fi
    export PKG_CONFIG_PATH="${pkgconfig_paths}"

    # Some libsharp link tests rely on symbols such as __muldc3 from
    # complex arithmetic builtins.
    CLANG_RT_BUILTINS_POSIX=""
    for cand in "${build_prefix_posix}"/Library/lib/clang/*/lib/windows/clang_rt.builtins-x86_64.lib; do
        if [ -f "${cand}" ]; then
            CLANG_RT_BUILTINS_POSIX="${cand}"
            CLANG_RT_BUILTINS_MS="$(cygpath -ms "${cand}")"
            export CLANG_RT_BUILTINS_POSIX
            export LDFLAGS="${LDFLAGS} -Wl,-defaultlib:${CLANG_RT_BUILTINS_MS}"
            break
        fi
    done

    CFITSIO_LIBS="$(pkg_config_libs cfitsio)"
    if [ -n "${CFITSIO_LIBS}" ]; then
        export CFITSIO_LIBS
    fi

    # Re-export MSVC + Windows SDK include/lib environment.
    # This build shell does not reliably preserve these
    # variables across the toolchain activation boundaries.
    win_sdk_ver="${WindowsSDKVersion%\\}"
    msvc_bin="$(cygpath -u "${VCToolsInstallDir}")bin/HostX64/x64"
    export INCLUDE="${VCToolsInstallDir}include;${WindowsSdkDir}Include\\${win_sdk_ver}\\ucrt;${WindowsSdkDir}Include\\${win_sdk_ver}\\um;${WindowsSdkDir}Include\\${win_sdk_ver}\\shared;${LIBRARY_INC}"
    export LIB="${VCToolsInstallDir}lib\\x64;${WindowsSdkDir}Lib\\${win_sdk_ver}\\ucrt\\x64;${WindowsSdkDir}Lib\\${win_sdk_ver}\\um\\x64;${LIBRARY_LIB}"
    export PATH="${msvc_bin}:${PATH}"
fi

for subdir in ./cextern/healpix/src/common_libraries/libsharp ./cextern/healpix/src/cxx; do
    pushd "${subdir}"

    # Get an updated config.sub and config.guess
    cp "${config_aux_dir}"/config.* ./

    if [ "${target_platform}" = "win-64" ] && [ "${subdir}" = "./cextern/healpix/src/cxx" ]; then
        # Windows/MSVC runtime does not provide m.lib; cxx configure hardcodes -lm.
        sed -i 's/SHARP_LIBS="\$SHARP_LIBS -lm"/SHARP_LIBS="\$SHARP_LIBS"/g' configure

        SHARP_LIBS="$(pkg_config_libs libsharp)"
        if [ -n "${SHARP_LIBS}" ]; then
            export SHARP_LIBS
        fi

        if [ -n "${CLANG_RT_BUILTINS_POSIX}" ] && [ -f "${CLANG_RT_BUILTINS_POSIX}" ]; then
            mkdir -p "${PREFIX}/lib"
            cp "${CLANG_RT_BUILTINS_POSIX}" "${PREFIX}/lib/clang_rt.builtins-x86_64.lib"
        fi
    fi

    ./configure --prefix="${PREFIX}"

    if [ "${target_platform}" = "win-64" ]; then
        if [ -f libtool ]; then
            patch_libtool
        fi

        if [ -f config/config.auto ]; then
            # MSVC/UCRT does not provide a separate libm import library.
            sed -i 's/[[:space:]]-lm\>/ /g' config/config.auto
        fi

        if [ "${subdir}" = "./cextern/healpix/src/cxx" ] && [ -f Makefile ]; then
            # On Windows, libtool builds static-only here. Explicitly propagate
            # transitive deps when linking cxx executables.
            sed -i 's|^LIBS = $|LIBS = $(SHARP_LIBS) $(CFITSIO_LIBS) $(libdir)/clang_rt.builtins-x86_64.lib|' Makefile
        fi
    fi

    make install
    popd
done

# Make sure that Cython-generated files are always generated by our
# own Cython. Motivated by https://github.com/healpy/healpy/issues/473 .

cython_files="
healpy/src/_query_disc.cpp
healpy/src/_sphtools.cpp
healpy/src/_pixelfunc.cpp
"

rm -f $cython_files

# Now we can proceed as usual.

exec $PYTHON -m pip install . --no-deps --ignore-installed --no-cache-dir -vvv
