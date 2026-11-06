# CT2-nx progress log

Newest first. One entry per session, with the evidence behind each decision.

## 2026-11-06: first PC boot test; jitter A/B next

- Built in 1,020 s (90 files from the patch set). Boot test, 120 guest s: title, menus and into
  gameplay. Mark: pretty smooth, but the picture looks jittery in motion.
- Gameplay at 0.99x to 1.00x, 59.8 to 59.9 fps shown and 59.9 renders/s, game thread 44 to 59%
  busy. Idle skip works: "the empty function at 0x0C154190, 2 wait loops", up to 83% of guest
  time skipped in menus. Early loading stretches at 0.40x to 0.66x with the game thread 85 to 91%
  busy, while the interpreter ran untranslated code.
- In play, 81 to 192 of every 300 refreshes found the render still in flight and presented
  without waiting (patch 0027): the GPU copy then shows the frame before, so frames mix one
  refresh late and on time, which can repeat one frame and skip the next. The likely cause of the
  jitter, not proven: the PC's display refresh (the Legion Go's screen can run at 144 Hz) would
  judder 60 fps too.
- Untranslated: 0x0C0814E6 (183,460 calls), 0x0C081E9A (15,691), 0x0C088720 (625),
  0x0C093CA4 (1), the same functions as Crazy Taxi's first four seeds; and 0x8C000000 and
  0x8C000600, 56,688 calls each. Mistake: Crazy Taxi 2's VBR is 0x8C000000, not Crazy Taxi's
  0x8C00F000, so the stub relocations went in at the wrong addresses. Fixed to 0x8C000000,
  0x8C000100, 0x8C000400 and 0x8C000600 (suggested.toml agrees); seeds added. No startup copies
  like Crazy Taxi's 0x8C004000 ones were suggested.
- Patch 0035: CT2_PRESENT_AB=N (boot_test.ps1 -PresentAB N) alternates every N game seconds
  between no-wait and waiting presents, logs each change ("present a/b: WAIT from 45.0 s") and
  puts WAIT or NO WAIT on the FPS counter. Syntax-checked with the Switch compiler.

## 2026-11-06: first PC build stopped before compiling

- build_pc.log held only its header; `out\dream-pin.tar` was left behind and
  `out\dream-patched\` was empty, so Apply-Patches stopped unpacking the pinned sources (the tar
  is intact: it unpacks on the bridge). Most likely `tar` on Mark's PATH is Git's GNU tar, which
  reads `C:\...` as a remote host. That step came from ZombieRev-nx's Switch phase and had not
  run on the PC before.
- Fix: Windows' own `System32\tar.exe` by full path, and the git and tar error text now goes
  into build_pc.log, so a failure there names its cause next time.

## 2026-11-06: kickoff

- Repo set up from ZombieRev-nx (the newest patch set 0001 to 0034, PC scripts, Switch layer),
  renamed to the game id `crazytaxi2` and SD folder `sdmc:/switch/crazytaxi2/`. Patch 0025 now
  names that folder; 0026's banner reads CRAZY TAXI 2. The whole set applies cleanly to 51a148c.
  New plain icon (no Sega art).
- Disc: `C:\CT2-nx\assets\Crazy Taxi 2 (USA).chd`, the same file (SHA-1 2aeaf26c...) as the one
  CTDC-nx extracted on 2026-11-03; that extraction was copied over (1ST_READ.BIN SHA-1
  bcff06e9..., as recorded). Prior art: none found for Crazy Taxi 2.
- `dcdisc scan`: code in 1ST_READ.BIN, 2_DP.BIN (Dream Passport browser, 2.8 MB), SG_DPLDR.BIN
  and MAIGO.BIN (14,856 bytes each). FCVDATA/FCVOPN/FCVSEL and PPLDC*.BIN are data. Only the
  main program is configured (offline port).
- Crazy Taxi's code in Crazy Taxi 2 (byte matching against CTDC-nx's 1ST_READ.BIN):
  - The four interrupt and exception stubs, identical apart from two literal pointers: relocations
    to 0x8C00F400, F500, F800 and FA00 from 0x0C166274, 0x0C1661E0 (twice) and 0x0C166218.
  - The wait loop (CTDC-nx fn_0c1582a0) at fn_0c155800, instruction for instruction, 0x2AA0 lower;
    the empty callback (rts; nop) at 0x0C154190, jsr sites 0x0C15595C and 0x0C15599C. Idle skip
    `0x0C154190:0x0C155960,0x0C1559A0` on the PC scripts and the Switch launcher, untested.
  - Crazy Taxi's startup copies to 0x8C004000 and 0x8C004E0C and its small routines at
    0x8C00EB90..0x8C00F720 do not match; left to the first boot test's suggestions.
- Cloud translation check (translator with patches through 0030): 5,186 functions, 1,596 with
  FP-mode copies, 35,380 FP runtime branches in generic bodies, about 176 MB of C++. PC builds in
  16 parts, Switch in 32.
