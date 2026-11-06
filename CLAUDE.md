# CT2-nx: notes for Claude

Native port of **Crazy Taxi 2** (Dreamcast, USA, MK-51136 V1.004) built with
[dream-recomp](https://github.com/phobos665/dream-recomp) static recompilation. PC first, then
Nintendo Switch homebrew (libnx). Owner: Mark (GitHub FurryLilManChild). Load `switch-port-base`
and `dreamcast-switch-port` before working here. Reference ports: CTDC-nx (Crazy Taxi, the same
engine: start there for any game question) and ZombieRev-nx (the newest patch set, scripts and
Switch layer, which this repo starts from), then SA-nx.

The name is CT2-nx (Mark's choice). Keep it everywhere; the game id in files is `crazytaxi2`.

## Who does what

- Claude writes all code, scripts and configs, reads logs, and commits.
- Mark runs the PowerShell scripts on his Windows PC, boot tests and play tests, and moves Switch
  builds to the SD card himself. He writes no code.
- Claude reaches `C:\CT2-nx` through the device bridge (a Linux shell with the folder
  mounted at `$HOME/mnt/CT2-nx`). That shell cannot run Windows programs, cannot delete
  files there, and stops anything still running when each call returns (about 3 minutes per call).
- PC builds run on Mark's PC, never in the cloud unless he agrees first. Switch NRO builds in the
  cloud are fine.

## Hard rules

- Never use em dashes anywhere (chat, docs, commits). No decorative emoji.
- Never commit game data: `assets/`, `games/*/extracted/`, saves, captures. Run `git status`
  before every commit.
- Commit as `FurryLilManChild <346934328+FurryLilManChild@users.noreply.github.com>`.
- dream-recomp stays pinned in the `dream-recomp` submodule (51a148c). Our changes to it go in
  `patches/dream-recomp/*.patch`, applied as one set by the build scripts. 0001 to 0034 came over
  from ZombieRev-nx (0001 to 0030 from CTDC-nx before it) and apply cleanly in order to the pin
  (checked 2026-11-06). Game-specific ones: 0022 (SA-nx's Switch layer, its 0x8C900000 module
  check), 0025 (SD folder `sdmc:/switch/crazytaxi2/`), 0026 (low-latency pacing only, banner
  "CRAZY TAXI 2"). Follow dream-recomp's own rules (its `.claude/skills/dream-recomp`): never
  paste Sega SDK text, every emitter change gets a differential test.
- Running or building third-party code (dream-recomp's libchdr on the bridge included) needs
  Mark's OK first.

## Upstreams and licences

| Upstream | Use | Licence |
|---|---|---|
| phobos665/dream-recomp @ 51a148c | recompiler, runtime, renderer, disc tools | GPL-2.0 |
| FurryLilManChild/ZombieRev-nx, CTDC-nx, SA-nx | patch set, scripts, Switch layer, Crazy Taxi config | GPL-2.0 |
| libsdl-org/SDL 3.4.16 (VC package) | window, input, audio on PC | zlib |

No prior Crazy Taxi 2 recomp, decomp or Switch port found (search 2026-11-06); sp00nznet/crazytaxi
is Crazy Taxi 1 only.

This repository is GPL-2.0 (dream-recomp's licence), see `COPYING`.

## Layout

```
dream-recomp/          submodule, pinned
games/crazytaxi2/      crazytaxi2.toml (config, committed), CMakeLists.txt, extracted/ (ignored)
assets/                Mark's CHD (ignored)
tools/extract_resumable.py   disc extraction in passes (the bridge's time limit)
tools/win/             setup_pc, build_pc, boot_test, play, trace_run, stage_switch (-Game)
switch/                build.sh, docker_build.sh, src/switch_main.cpp, egl_stubs.c, icon.jpg (from
                       ZombieRev-nx, renamed; built in the cloud as in CTDC-nx)
docs/progress-log.md   newest first, one entry per session with evidence
```

## The loop (PC phase)

1. Claude changes config or code, commits, pushes.
2. Mark runs, always given in exactly this form (his PowerShell blocks bare `.ps1` scripts):
   ```
   git pull
   powershell -ExecutionPolicy Bypass -File tools\win\build_pc.ps1
   powershell -ExecutionPolicy Bypass -File tools\win\boot_test.ps1
   ```
3. Claude reads `out\logs\*` through the bridge (boot.log, boot-report.txt, suggested.toml),
   merges suggested seeds into the toml with evidence in the progress log, presents findings and
   the next plan, and waits for Mark's go-ahead.

## Reading CHDs from the bridge

The bridge's Linux shell has no chdman. dream-recomp's `dcdisc` reads CHDs through libchdr: build
`third_party/libchdr/unity.c` plus `src/libchdr_codec_avhuff.c` into a shared library with gcc and
point `DCDISC_LIBCHDR` at it. The bridge workspace is wiped between sessions.

## Disc facts

| | Crazy Taxi 2 (USA) |
|---|---|
| CHD file | `assets/Crazy Taxi 2 (USA).chd`, 123,321,529 bytes, SHA-1 of the file 2aeaf26c59757dd3c9b878824e5353c26812c7ac (the same file as `C:\CTDC-nx\assets\`) |
| CHD SHA-1 (data, as CTDC-nx recorded it) | 348a032208d610d572b89825d047e8f94646fea9 |
| Product | MK-51136 V1.004 (2001-05-02) |
| Track 1 SHA-1 | 15de448964d684e0bc51dbed8470eb15b811a687 |
| Track 2 SHA-1 | a3705cb0ce53c7adf906c5af76887406984de6a9 (the same as Crazy Taxi's) |
| Track 3 SHA-1 | 858ab545521727433d9e15cb44eb677f1afcfdb4 |
| Files | 167, 153 MB |
| 1ST_READ.BIN | 1,452,148 bytes, plain, SHA-1 bcff06e9defcd454d99ada84b9d26757e8ab4221 |

- Track hashes from CTDC-nx (raw 2352-byte sectors as dcdisc reads them). Not checked against
  Redump. `games/crazytaxi2/extracted/` was copied from CTDC-nx's extraction of the same file.
- Katana SDK title (Shinobi, Kamui, ADX banners), not Windows CE.
- Other code files: `2_DP.BIN` (the bundled Dream Passport browser), `SG_DPLDR.BIN` and
  `MAIGO.BIN` (small loaders). Not configured; see the toml.
- Much of the main program is Crazy Taxi's: its interrupt stubs and its wait loop are byte for
  byte the same at shifted addresses (stubs at 0x0C1661E0..0x0C1662A8, the wait loop 0x2AA0
  lower). Matching Crazy Taxi's bytes in this binary (CTDC-nx addresses) finds most equivalents.
- Translated with FP-mode copies: 5,186 functions, 1,596 copied, about 176 MB of C++ (PC 16
  parts, Switch 32).
