@echo on

setlocal EnableExtensions

if defined MSYS2_ENV_CONV_EXCL (
  set "MSYS2_ENV_CONV_EXCL=%MSYS2_ENV_CONV_EXCL%;LIB;INCLUDE;LIBPATH"
) else (
  set "MSYS2_ENV_CONV_EXCL=LIB;INCLUDE;LIBPATH"
)

call %BUILD_PREFIX%\Library\bin\run_autotools_clang_conda_build.bat
if %ERRORLEVEL% neq 0 exit 1
