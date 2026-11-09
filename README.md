# CT2-nx

A native Nintendo Switch port of **Crazy Taxi 2** for the Sega Dreamcast, made by static
recompilation with [dream-recomp](https://github.com/phobos665/dream-recomp). This is the
Dreamcast version. The sister project of [CTDC-nx](https://github.com/FurryLilManChild/CTDC-nx)
(Crazy Taxi), on the same engine.

The game's own code is translated from the Dreamcast's SH-4 to native code ahead of time, and
runs on a recreation of the Dreamcast's hardware: graphics through Vulkan, sound through a
recreated sound chip, and the memory card as a file on the SD card.

## Status

Version 0.5.0. Crazy Taxi 2 plays from start to finish on the Switch: Around Apple and Small
Apple, Arcade and Original, the Crazy Pyramid, options, saving and loading, and records.

- Full speed at 1224 MHz, the smallest CPU step above the system clock. A fresh install starts
  there. At the system's own clock (1020 MHz) the busiest scenes run at about 0.9x speed.
- 60 frames a second. Each frame is shown as soon as it is drawn, one screen refresh later.
- Your saves live in `sdmc:/switch/crazytaxi2/save/vmu_A1.bin`, a memory card image.
- All of the game's code is translated: nothing runs through an interpreter.

## Known issues

- At the system clock (1020 MHz) busy scenes slow down to about 0.9x. The default of 1224 MHz
  avoids this. If you use sys-clk or Horizon OC, a profile there can override the port's own
  setting.
- Resolution 1.5x and 2x need more than the default clocks to hold full speed in busy scenes;
  raise the CPU and GPU clocks in the port menu to use them.
- No vibration: the Jump Pack is not emulated yet. The option can be switched on in the game, it
  just does nothing.
- The game's online features (rankings and replay sharing through its bundled Dream Passport
  browser) are not supported.

## You need

- A Switch running custom firmware (Atmosphere) with the homebrew menu.
- Your own dump of the **USA** disc, as a CHD (one file) or a GDI (a .gdi file and its tracks).
  No game data is included in this project or its releases.

| Game | Product | Track 3 SHA-1 (raw 2352-byte sectors) |
|---|---|---|
| Crazy Taxi 2 (USA) | MK-51136 V1.004 | 858ab545521727433d9e15cb44eb677f1afcfdb4 |

## Install

1. Download `CT2-nx-0.5.0.zip` from the Releases page.
2. Extract it to the root of your SD card. It creates `sdmc:/switch/crazytaxi2/`.
3. Copy your disc dump into `sdmc:/switch/crazytaxi2/disc/`: the .chd file, or the .gdi file
   with all of its track files. Any file name works, as long as it is the only dump there.
4. Start the homebrew menu through **title takeover**: hold R while starting any game. The
   Album applet does not give homebrew enough memory.
5. Pick Crazy Taxi 2. The first start takes the game's main program off your disc and saves it
   next to the NRO, so later starts are quicker.

CT2-nx and CTDC-nx keep separate folders and saves, so both can be installed at once.

## Playing

- The Switch's buttons stand in for the Dreamcast controller's, with Plus as Start. The
  triggers are either fully pressed or not at all. The controls menu shows and changes the
  layout.
- **Minus** opens the port menu: controls, frame counter, screen shape, volume, resolution in
  game, CPU, GPU and memory clocks, and quitting.

## Reporting problems

Open an issue and attach the files from `sdmc:/switch/crazytaxi2/`:

- `crazytaxi2.log` and `crazytaxi2.err.log` (this run) and `crazytaxi2.prev.log` and
  `crazytaxi2.prev.err.log` (the one before),
- any `crash_*.txt`.

Say what you were doing when it happened, and which CPU clock the port menu showed.

## Build

The Switch build runs on Linux, in devkitPro's toolchain image with NVK:

```
git submodule update --init --recursive
RELEASE=1 ./switch/docker_build.sh
```

It needs `games/crazytaxi2/extracted/fs/1ST_READ.BIN` from your own disc, and writes
`out/sd/switch/crazytaxi2/`. dream-recomp stays on its pinned commit; this project's changes to
it are the patches in `patches/dream-recomp/`, applied by the build. A PC build (Windows,
`tools/win/`) is used for development. `CLAUDE.md` and `docs/progress-log.md` have the details
and the history.

## Credits and licence

- dream-recomp by phobos665 (GPL-2.0): the recompiler, runtime and renderer.
- CTDC-nx, ZombieRev-nx and SA-nx: the patch set, scripts and Switch layer this builds on.
- Flycast, KallistiOS and dreamcast.wiki for hardware documentation, by way of dream-recomp.
- NVK (Mesa) for Vulkan on the Switch, from ghcr.io/danfromtico/switch-dev-legacy-vulkan (MIT).
- devkitPro and libnx.

GPL-2.0, see `COPYING`. Crazy Taxi 2 is a Sega game; this project is not affiliated with or
endorsed by Sega.
