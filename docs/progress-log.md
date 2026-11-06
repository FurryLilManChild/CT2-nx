# CT2-nx progress log

Newest first. One entry per session, with the evidence behind each decision.

## 2026-11-06: depth A/B result; the flicker is a texture race, not depth

- Mark: no change in any depth variant. 15 captures; 005 to 014 at a building where the flicker
  was strong (F11).
- What the captures show: the building's lower facade (a stone band and the glass above the
  entrance, top left) is a flat blue-grey slab in 010, 013 and 014 and correct in 009, 011 and
  012, with the camera almost still.
- The display lists of 009 and 010 hold the same strips in that area (tadump, a small display
  list dumper on dream-recomp's DisplayList; only the HUD text differs). The opaque strips there
  use depth mode 4 (greater), cull mode 2 or 3: so the tie bias (modes 6 and 3 only) never applied.
- Re-rendering 010 offline (tools/rcap on lavapipe, from the capture's list, video memory and
  registers) draws the facade correctly, in every translucency mode and with greater-or-equal
  depth. The same list and the same video memory give the right picture; the game's own render of
  it did not. So the facade's texture was decoded from video memory holding something else at the
  moment the render thread read it.
- The render thread decodes textures from live video memory after the game thread has moved on
  (boot_main.cpp says so: "which the guest could be writing at that moment"). Crazy Taxi 2
  streams the city's textures while driving; a texture slot rewritten between the render's start
  and the render thread's decode shows the new contents, and the next frame's invalidation
  corrects it: the flicker. Not yet proven on the PC.
- Test: boot_test.ps1 -RenderOnGameThread (DREAM_RENDER_THREAD=0) draws on the game thread as each
  render starts, reading video memory as the game left it then. No rebuild needed. If the flicker
  is gone, the fix is to hold the game's video memory writes while a render is still reading
  textures, keeping the render thread.

## 2026-11-06: translucency A/B result; depth ties next

- Mark: the flicker did not change with the translucency mode; it shows most on painted road
  lines, in all three modes. No F11 capture taken.
- Reading: depth fighting between the road and the lines painted on it. The renderer writes
  pvr_depth(1/w) per pixel (Flycast's log mapping); two triangles on one plane interpolate 1/w a
  hair apart, so a greater-or-equal tie the hardware would pass comes out either way. Not yet
  confirmed from a capture (which depth comparison the lines use is the open question).
- Patch 0037: Renderer::depth_variant, applied in geometry.frag (opaque and punch-through): 0 as
  computed, 1 +1e-6 for greater-or-equal (-1e-6 for less-or-equal) so the later polygon wins a
  tie, 2 depth rounded to 2^-20. CT2_DEPTH_AB=N cycles them (boot_test.ps1 -DepthAB N) with the
  label on the FPS counter; CT2_CAPTURE_EVERY=N (-CaptureEvery N) writes a capture every N game
  seconds, so frames of the flicker reach Claude without a key press. Launcher, renderer and
  shader compile-checked here (Switch compiler, glslc).

## 2026-11-06: present A/B result; ground flicker next

- Second PC boot test (998 s build, 144 guest s, `-PresentAB 15`): untranslated call targets 0
  (the seeds and the stub relocations at 0x8C000000 took everything); loading now 0.92x to 0.99x;
  play at 0.97x to 1.00x, 59.9 fps shown, game thread 41 to 51% busy.
- Mark: WAIT is clearly the better of the two. The jitter he reported was mostly something else:
  textures flickering on the ground (while picking up a fare), in both WAIT and NO WAIT.
- Unmapped accesses: 5 single reads at boot (0xA0600000/4 and 0xA1000400/800/1400), the G2 bus
  where a modem or network adapter would answer: the game looking for its online hardware.
- Patch 0036: waiting is the default; no-wait only with CT2_NO_WAIT (or inside the present a/b).
  CT2_TRANSLUCENCY_AB=N (boot_test.ps1 -TranslucencyAB N) cycles per triangle, per pixel and per
  strip every N game seconds, logged and on the FPS counter. If the flicker follows the mode, it is
  translucent sorting; if it is there in all three, it is something else (depth fighting between
  ground polygons, or a texture), and an F11 capture at the spot can be rendered offline here.

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
