# CT2-nx progress log

Newest first. One entry per session, with the evidence behind each decision.

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
