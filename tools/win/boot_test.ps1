# Boots the game for up to 120 GAME seconds in a window, then closes it. Game time runs slower
# than real time while code still goes through the interpreter. Writes:
#   out\logs\boot.log          everything the launcher printed
#   out\logs\boot-report.txt   where the run got to and why it stopped
#   out\logs\suggested.toml    code the run reached that is not translated yet (Claude merges it)
#   powershell -ExecutionPolicy Bypass -File tools\win\boot_test.ps1 [-Seconds 120] [-Headless] [-PresentAB 15] [-TranslucencyAB 10] [-DepthAB 10] [-CaptureEvery 20] [-RenderOnGameThread]
#   -RenderOnGameThread: draw on the game thread as each render starts (DREAM_RENDER_THREAD=0),
#   so textures are read from video memory as the game left it at that moment.
#   -PresentAB N: every N game seconds, switch between showing frames without waiting for the one
#   being drawn and waiting for it (CT2-nx patch 0035); the FPS counter shows WAIT or NO WAIT.
#   Waiting is the default since patch 0036.
#   -TranslucencyAB N: every N game seconds, the next translucency mode (per triangle, per pixel,
#   per strip; patch 0036), shown on the FPS counter. F11 writes a capture-NNN.* set to C:\CT2-nx.
#   -DepthAB N: every N game seconds, the next way of writing depth (as computed, tie bias,
#   rounded; patch 0037), shown on the FPS counter. -CaptureEvery N: a capture every N game seconds.
param([int]$Seconds = 120, [switch]$Headless, [int]$PresentAB = 0, [int]$TranslucencyAB = 0, [int]$DepthAB = 0, [int]$CaptureEvery = 0, [switch]$RenderOnGameThread, [string]$Game = 'crazytaxi2')
. "$PSScriptRoot\common.ps1"
if (-not (Test-Path $GameExe)) { throw 'Not built yet. Run tools\win\build_pc.ps1 first.' }
Start-Log 'boot.log' "boot_test $GameId $Seconds s" | Out-Null

$a = @('--config', $GameToml, '--max-seconds', $Seconds,
       '--report', (Join-Path $LogDir 'boot-report.txt'),
       '--suggest-config', (Join-Path $LogDir 'suggested.toml'))
# Start on CPU register bank 1 (SR.RB = 1), the state SA-nx needed (taken from a captured real
# boot). Expected to be the boot ROM's hand-off for every game, so Crazy Taxi 2 starts the same way (CTDC-nx: Crazy Taxi does).
# Not yet confirmed for Crazy Taxi 2: if a boot misbehaves, a run without it is a cheap check.
$a += @('--boot-sr', '0x600000F1')
# Memory card: created blank on first run, kept between runs (out\saves\<game>_vmu_A1.bin).
$a += @('--vmu', $VmuFile)
# Port menu options (frame pacing, FPS counter) and a timing line every five seconds in the log.
$a += @('--options', $OptionsFile, '--perf-log')
# The game's wait loops call an empty function until an interrupt; jump the clock instead
# (switch_main.cpp has the details).
if ($GameId -eq 'crazytaxi2') { $a += @('--idle-skip', '0x0C154190:0x0C155960,0x0C1559A0', '--whole-game') }
if (-not $Headless) { $a += '--window' }
if ($PresentAB -gt 0) { $env:CT2_PRESENT_AB = "$PresentAB" } else { Remove-Item Env:CT2_PRESENT_AB -ErrorAction SilentlyContinue }
if ($RenderOnGameThread) { $env:DREAM_RENDER_THREAD = '0' } else { Remove-Item Env:DREAM_RENDER_THREAD -ErrorAction SilentlyContinue }
if ($DepthAB -gt 0) { $env:CT2_DEPTH_AB = "$DepthAB" } else { Remove-Item Env:CT2_DEPTH_AB -ErrorAction SilentlyContinue }
if ($CaptureEvery -gt 0) { $env:CT2_CAPTURE_EVERY = "$CaptureEvery" } else { Remove-Item Env:CT2_CAPTURE_EVERY -ErrorAction SilentlyContinue }
if ($TranslucencyAB -gt 0) { $env:CT2_TRANSLUCENCY_AB = "$TranslucencyAB" } else { Remove-Item Env:CT2_TRANSLUCENCY_AB -ErrorAction SilentlyContinue }
Write-Host "Booting $GameId for up to $Seconds game seconds (more in real time while it runs slow) ..."
$rc = Invoke-Logged $GameExe $a 'boot' '^frame'
Write-Host "Finished (exit $rc). Tell Claude the boot test is done; logs are in out\logs."
