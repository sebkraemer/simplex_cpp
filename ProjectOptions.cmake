include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(simplex_cpp_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(simplex_cpp_setup_options)
  option(simplex_cpp_ENABLE_HARDENING "Enable hardening" ON)
  option(simplex_cpp_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    simplex_cpp_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    simplex_cpp_ENABLE_HARDENING
    OFF)

  simplex_cpp_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR simplex_cpp_PACKAGING_MAINTAINER_MODE)
    option(simplex_cpp_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(simplex_cpp_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(simplex_cpp_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(simplex_cpp_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(simplex_cpp_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(simplex_cpp_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(simplex_cpp_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(simplex_cpp_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(simplex_cpp_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(simplex_cpp_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(simplex_cpp_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(simplex_cpp_ENABLE_PCH "Enable precompiled headers" OFF)
    option(simplex_cpp_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(simplex_cpp_ENABLE_IPO "Enable IPO/LTO" ON)
    option(simplex_cpp_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(simplex_cpp_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(simplex_cpp_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(simplex_cpp_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(simplex_cpp_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(simplex_cpp_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(simplex_cpp_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(simplex_cpp_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(simplex_cpp_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(simplex_cpp_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(simplex_cpp_ENABLE_PCH "Enable precompiled headers" OFF)
    option(simplex_cpp_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      simplex_cpp_ENABLE_IPO
      simplex_cpp_WARNINGS_AS_ERRORS
      simplex_cpp_ENABLE_USER_LINKER
      simplex_cpp_ENABLE_SANITIZER_ADDRESS
      simplex_cpp_ENABLE_SANITIZER_LEAK
      simplex_cpp_ENABLE_SANITIZER_UNDEFINED
      simplex_cpp_ENABLE_SANITIZER_THREAD
      simplex_cpp_ENABLE_SANITIZER_MEMORY
      simplex_cpp_ENABLE_UNITY_BUILD
      simplex_cpp_ENABLE_CLANG_TIDY
      simplex_cpp_ENABLE_CPPCHECK
      simplex_cpp_ENABLE_COVERAGE
      simplex_cpp_ENABLE_PCH
      simplex_cpp_ENABLE_CACHE)
  endif()

  simplex_cpp_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (simplex_cpp_ENABLE_SANITIZER_ADDRESS OR simplex_cpp_ENABLE_SANITIZER_THREAD OR simplex_cpp_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(simplex_cpp_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(simplex_cpp_global_options)
  if(simplex_cpp_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    simplex_cpp_enable_ipo()
  endif()

  simplex_cpp_supports_sanitizers()

  if(simplex_cpp_ENABLE_HARDENING AND simplex_cpp_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR simplex_cpp_ENABLE_SANITIZER_UNDEFINED
       OR simplex_cpp_ENABLE_SANITIZER_ADDRESS
       OR simplex_cpp_ENABLE_SANITIZER_THREAD
       OR simplex_cpp_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${simplex_cpp_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${simplex_cpp_ENABLE_SANITIZER_UNDEFINED}")
    simplex_cpp_enable_hardening(simplex_cpp_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(simplex_cpp_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(simplex_cpp_warnings INTERFACE)
  add_library(simplex_cpp_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  simplex_cpp_set_project_warnings(
    simplex_cpp_warnings
    ${simplex_cpp_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(simplex_cpp_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    simplex_cpp_configure_linker(simplex_cpp_options)
  endif()

  include(cmake/Sanitizers.cmake)
  simplex_cpp_enable_sanitizers(
    simplex_cpp_options
    ${simplex_cpp_ENABLE_SANITIZER_ADDRESS}
    ${simplex_cpp_ENABLE_SANITIZER_LEAK}
    ${simplex_cpp_ENABLE_SANITIZER_UNDEFINED}
    ${simplex_cpp_ENABLE_SANITIZER_THREAD}
    ${simplex_cpp_ENABLE_SANITIZER_MEMORY})

  set_target_properties(simplex_cpp_options PROPERTIES UNITY_BUILD ${simplex_cpp_ENABLE_UNITY_BUILD})

  if(simplex_cpp_ENABLE_PCH)
    target_precompile_headers(
      simplex_cpp_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(simplex_cpp_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    simplex_cpp_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(simplex_cpp_ENABLE_CLANG_TIDY)
    simplex_cpp_enable_clang_tidy(simplex_cpp_options ${simplex_cpp_WARNINGS_AS_ERRORS})
  endif()

  if(simplex_cpp_ENABLE_CPPCHECK)
    simplex_cpp_enable_cppcheck(${simplex_cpp_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(simplex_cpp_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    simplex_cpp_enable_coverage(simplex_cpp_options)
  endif()

  if(simplex_cpp_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(simplex_cpp_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(simplex_cpp_ENABLE_HARDENING AND NOT simplex_cpp_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR simplex_cpp_ENABLE_SANITIZER_UNDEFINED
       OR simplex_cpp_ENABLE_SANITIZER_ADDRESS
       OR simplex_cpp_ENABLE_SANITIZER_THREAD
       OR simplex_cpp_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    simplex_cpp_enable_hardening(simplex_cpp_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
