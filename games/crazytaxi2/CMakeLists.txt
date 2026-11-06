# Crazy Taxi 2. Everything is in cmake/DreamAddGame.cmake; this file exists so that adding a game
# is adding a directory. Add BOOT_TEST once the title boots far enough to be worth asserting on.
dream_add_game(crazytaxi2 TITLE "Crazy Taxi 2")

# Every guest call, and every jump between translated functions, is a host call. Windows gives the
# main thread 1 MB of stack, which SA-nx overflowed in play (0xC00000FD). 256 MB, reserved not
# committed, so it costs nothing unless used.
if(MSVC)
  target_link_options(crazytaxi2_boot PRIVATE /STACK:268435456)
endif()

# All of the game's translated code at the compiler's full optimisation (dream-recomp builds it at
# -O1 to keep big games' builds short). CTDC-nx gained about 15% at the Switch's stock clock from
# this (SA-nx nothing), so it is game-dependent; Crazy Taxi 2 is not yet measured (same engine as Crazy Taxi).
# -fno-strict-aliasing because translated code reads guest memory through casts that -O2 would
# otherwise be entitled to reorder. Not MSVC: PC builds stay as they were.
if(NOT MSVC)
  set(_ct2_units ${CMAKE_CURRENT_BINARY_DIR}/gen/crazytaxi2.cpp)
  foreach(_k RANGE 1 96)
    list(APPEND _ct2_units ${CMAKE_CURRENT_BINARY_DIR}/gen/crazytaxi2_part${_k}.cpp)
  endforeach()
  set_source_files_properties(${_ct2_units} PROPERTIES COMPILE_OPTIONS "-O2;-fno-strict-aliasing")
endif()

# The Switch: Horizon's own main() around the launcher, and the NRO the homebrew menu runs.
# switch/build.sh configures this with devkitPro's toolchain.
if(NINTENDO_SWITCH)
  target_sources(crazytaxi2_boot PRIVATE ${CMAKE_SOURCE_DIR}/switch/src/switch_main.cpp
    ${CMAKE_SOURCE_DIR}/switch/src/egl_stubs.c)
  target_link_libraries(crazytaxi2_boot PRIVATE nx)
  # A cache in front of libgcc's FDE search for C++ exception unwinding (SA-nx switch-test28,
  # switch_main.cpp's __wrap__Unwind_Find_FDE).
  target_link_options(crazytaxi2_boot PRIVATE -Wl,--wrap=_Unwind_Find_FDE)
  # Version shown in the homebrew menu. A plain variable, not a cache entry: a cached one kept an
  # existing build directory at its old version (CTDC-nx 0.5.0 went out reading 0.1.0).
  set(CT2_VERSION "0.5.0")
  # A release: no end-of-run report, no profiler, quick exit (switch_main.cpp).
  option(CT2_RELEASE "Build the Switch launcher as a release" OFF)
  if(CT2_RELEASE)
    set_source_files_properties(${CMAKE_SOURCE_DIR}/switch/src/switch_main.cpp
      PROPERTIES COMPILE_DEFINITIONS CT2_RELEASE=1)
  endif()
  nx_generate_nacp(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/crazytaxi2.nacp
    NAME "Crazy Taxi 2 (CT2-nx)"
    AUTHOR "CT2-nx"
    VERSION "${CT2_VERSION}")
  nx_create_nro(crazytaxi2_boot NACP ${CMAKE_CURRENT_BINARY_DIR}/crazytaxi2.nacp
    ICON ${CMAKE_SOURCE_DIR}/switch/icon.jpg)
endif()
