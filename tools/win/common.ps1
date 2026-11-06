# Shared helpers for the CT2-nx Windows scripts. Dot-source it: . "$PSScriptRoot\common.ps1"
# Scripts that take -Game set $Game before dot-sourcing; crazytaxi2 is the default.
# Logs are written as UTF-8 to out\logs so Claude can read them through the bridge.

$ErrorActionPreference = 'Stop'
$Root    = (Resolve-Path "$PSScriptRoot\..\..").Path
$LogDir  = Join-Path $Root 'out\logs'
$BuildDir = Join-Path $Root 'build-pc'
$DepsDir = Join-Path $Root '.deps'
$Sdl3Dir = Join-Path $DepsDir 'SDL3-3.4.16'
if (-not $Game) { $Game = 'crazytaxi2' }
$GameId  = $Game
$GameToml = Join-Path $Root "games\$GameId\$GameId.toml"
$GameExe = Join-Path $BuildDir "games\$GameId\${GameId}_boot.exe"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
# The game's memory card (VMU) lives here between runs (out\ is never committed).
$SaveDir = Join-Path $Root 'out\saves'
$VmuFile = Join-Path $SaveDir "${GameId}_vmu_A1.bin"
New-Item -ItemType Directory -Force -Path $SaveDir | Out-Null
# The port menu's options (F1 opens it), kept between runs. Created on first use with low-latency
# frame pacing and the FPS counter on. SA-nx's "smooth" pacing keeps the last frame up whenever the
# render thread is still drawing; that suits a 30 fps game, but a 60 fps game (Crazy Taxi) showed
# about 35 of its 58 frames a second with it (CTDC-nx, 2026-11-03).
$OptionsFile = Join-Path $SaveDir "${GameId}_options.txt"
if (-not (Test-Path $OptionsFile)) {
    [IO.File]::WriteAllText($OptionsFile, "SHOW_FPS=1`r`n", (New-Object Text.UTF8Encoding $false))
}

# The diagnostic build (build_pc.ps1 -Trace, trace_run.ps1) lives in its own folder.
function Use-TraceBuild {
    $script:BuildDir = Join-Path $Root 'build-trace'
    $script:GameExe = Join-Path $script:BuildDir "games\$GameId\${GameId}_boot.exe"
}

function Write-Log([string]$File, [string]$Text) {
    [IO.File]::AppendAllText((Join-Path $LogDir $File), $Text + "`r`n", (New-Object Text.UTF8Encoding $false))
}

function Start-Log([string]$File, [string]$Title) {
    $p = Join-Path $LogDir $File
    [IO.File]::WriteAllText($p, "== $Title  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n", (New-Object Text.UTF8Encoding $false))
    return $p
}

# Puts the x64 MSVC compiler, linker and Windows SDK on PATH for this PowerShell window.
function Enter-DevShell {
    if (Get-Command cl.exe -ErrorAction SilentlyContinue) { return }
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) { throw 'Visual Studio 2022 (or its Build Tools) is not installed. Run tools\win\setup_pc.ps1 first.' }
    $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vs) { throw 'No Visual Studio install with the C++ x64 tools. Run tools\win\setup_pc.ps1 first.' }
    Import-Module (Join-Path $vs 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll')
    Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64' | Out-Null
}

# Windows CMake and Ninja, never MSYS2 or Git-for-Windows copies (devkitPro installs MSYS2, and
# its cmake turns C:\CT2-nx into /c/CT2-nx/C:/CT2-nx). Visual Studio's bundled copies come first.
function Find-WinTool([string]$Name) {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $cands = @()
    if (Test-Path $vswhere) {
        $vs = & $vswhere -latest -products * -property installationPath
        if ($vs) {
            $ext = Join-Path $vs 'Common7\IDE\CommonExtensions\Microsoft\CMake'
            if ($Name -eq 'cmake') { $cands += Join-Path $ext 'CMake\bin\cmake.exe' }
            if ($Name -eq 'ninja') { $cands += Join-Path $ext 'Ninja\ninja.exe' }
        }
    }
    if ($Name -eq 'cmake') { $cands += "$env:ProgramFiles\CMake\bin\cmake.exe" }
    $cands += (Get-Command "$Name.exe" -All -ErrorAction SilentlyContinue | ForEach-Object { $_.Source })
    foreach ($c in $cands) {
        if ($c -and (Test-Path $c) -and ($c -notmatch '(?i)msys|devkitpro|\\usr\\bin|\\mingw')) { return $c }
    }
    throw "No Windows $Name.exe found. Run tools\win\setup_pc.ps1 (it installs one), then try again."
}

# Applies patches\dream-recomp\*.patch to the submodule as one set, in name order. Later patches
# may edit lines earlier ones added, so a patch cannot be checked on its own. A stamp records which
# set is applied; when the set changes, the submodule is reset to its pinned files and the whole
# set is applied again. Unchanged set: nothing is touched, so nothing is rebuilt.
function Apply-Patches {
    $sub = Join-Path $Root 'dream-recomp'
    $stamp = Join-Path $Root 'out\dream-patches.stamp'
    $patches = @(Get-ChildItem (Join-Path $Root 'patches\dream-recomp\*.patch') | Sort-Object Name)
    $sha = [Security.Cryptography.SHA256]::Create()
    $all = New-Object IO.MemoryStream
    foreach ($p in $patches) { $b = [IO.File]::ReadAllBytes($p.FullName); $all.Write($b, 0, $b.Length) }
    $want = -join ($sha.ComputeHash($all.ToArray()) | ForEach-Object { $_.ToString('x2') })
    $have = ''
    if (Test-Path $stamp) { $have = (Get-Content $stamp -Raw).Trim() }
    if ($have -eq $want) { return }

    $ErrorActionPreference = 'Continue'  # git writes progress and notes to stderr
    Write-Host 'Applying dream-recomp patches ...'
    # ZombieRev-nx: the set is applied to a fresh copy of the pinned sources in out\, and only
    # files whose bytes differ are copied into the submodule. Resetting the submodule in place gave
    # every patched file a new time stamp, so one small runtime patch rebuilt the whole game.
    $patched = Join-Path $Root 'out\dream-patched'
    $tarFile = Join-Path $Root 'out\dream-pin.tar'
    if (Test-Path $patched) { Remove-Item $patched -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $patched | Out-Null
    # The commit the superproject pins, not the submodule's HEAD.
    $pin = (& git -C $Root rev-parse HEAD:dream-recomp).Trim()
    $msg = & git -C $sub archive -o $tarFile $pin 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log 'build_pc.log' "git archive failed: $msg"
        throw 'git archive of dream-recomp failed. Tell Claude.'
    }
    # CT2-nx: Windows' own tar (bsdtar) by full path. A plain `tar` can be Git's GNU tar, which
    # reads "C:\..." as a remote host and fails (CT2-nx's first PC build, 2026-11-06).
    $tarExe = Join-Path $env:SystemRoot 'System32\tar.exe'
    if (-not (Test-Path $tarExe)) { $tarExe = 'tar' }
    Write-Log 'build_pc.log' "unpacking the pinned sources with $tarExe"
    $msg = & $tarExe -xf $tarFile -C $patched 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log 'build_pc.log' "unpacking failed: $msg"
        throw 'Unpacking dream-recomp failed. Tell Claude.'
    }
    Remove-Item $tarFile -Force
    & git -C $patched init -q 2>&1 | Out-Null
    foreach ($p in $patches) {
        $msg = & git -C $patched apply --whitespace=nowarn $p.FullName 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log 'build_pc.log' "patch $($p.Name) failed: $msg"
            throw "Patch $($p.Name) does not apply. Tell Claude."
        }
        Write-Log 'build_pc.log' "applied $($p.Name)"
    }
    $changed = 0
    $gitDir = Join-Path $patched '.git'
    foreach ($f in Get-ChildItem $patched -Recurse -File -Force) {
        if ($f.FullName.StartsWith($gitDir)) { continue }
        $rel = $f.FullName.Substring($patched.Length + 1)
        $dst = Join-Path $sub $rel
        $same = $false
        if (Test-Path $dst) {
            $same = (Get-FileHash $f.FullName -Algorithm SHA256).Hash -eq (Get-FileHash $dst -Algorithm SHA256).Hash
        }
        if (-not $same) {
            New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
            Copy-Item $f.FullName $dst -Force
            (Get-Item $dst).LastWriteTime = Get-Date
            $changed++
        }
    }
    # Files an earlier set added (untracked, not ignored) that this set no longer has: removed.
    foreach ($rel in (& git -C $sub ls-files --others --exclude-standard)) {
        $dst = Join-Path $sub $rel
        if ((Test-Path $dst -PathType Leaf) -and -not (Test-Path (Join-Path $patched $rel))) {
            Remove-Item $dst -Force; $changed++
        }
    }
    Remove-Item $patched -Recurse -Force
    Write-Host "  $($patches.Count) patches, $changed files changed in dream-recomp"
    Write-Log 'build_pc.log' "$changed files changed in dream-recomp"
    [IO.File]::WriteAllText($stamp, $want)
}

# Parallel compile jobs: one per logical core, but no more than one per 3 GB of RAM, since each
# 10 MB piece of translated game code needs a few GB to compile.
function Get-BuildJobs {
    $cores = [Environment]::ProcessorCount
    $ramGb = [math]::Floor((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    return [math]::Max(1, [math]::Min($cores, [math]::Floor($ramGb / 3)))
}

# Runs a program with its output going straight to a UTF-8 log, and every few seconds shows the
# newest progress line (Ninja's [n/N]) so a long build is not a silent window.
function Invoke-Logged([string]$Exe, [string[]]$ArgList, [string]$LogName, [string]$Pattern = '^\[\d+/\d+\]') {
    $out = Join-Path $LogDir "$LogName.out.tmp"
    $err = Join-Path $LogDir "$LogName.err.tmp"
    # Windows PowerShell 5.1 joins -ArgumentList with plain spaces, so quote anything that has one.
    $quoted = $ArgList | ForEach-Object { if ("$_" -match '\s') { '"' + $_ + '"' } else { "$_" } }
    $p = Start-Process -FilePath $Exe -ArgumentList $quoted -NoNewWindow -PassThru `
        -RedirectStandardOutput $out -RedirectStandardError $err -WorkingDirectory $Root
    $null = $p.Handle  # without this, Windows PowerShell 5.1 loses the exit code
    $last = ''
    while (-not $p.HasExited) {
        Start-Sleep -Seconds 5
        if (Test-Path $out) {
            # Visual Studio prints thousands of C4702 warnings for each big game unit, so look well back
            # (40 lines showed "1 of 26" for half an hour while 11 units had finished).
            $line = Get-Content $out -Tail 20000 -ErrorAction SilentlyContinue | Where-Object { $_ -match $Pattern } | Select-Object -Last 1
            if ($line -and $line -ne $last) {
                $m = [regex]::Match($line, '^\[(\d+)/(\d+)\]')
                if ($m.Success) { Write-Host ("  {0} of {1} steps" -f $m.Groups[1].Value, $m.Groups[2].Value) }
                else { Write-Host "  $line" }
                $last = $line
            }
        }
    }
    $p.WaitForExit()
    $code = $p.ExitCode
    $log = Join-Path $LogDir "$LogName.log"
    foreach ($f in @($out, $err)) {
        if (Test-Path $f) {
            [IO.File]::AppendAllText($log, [IO.File]::ReadAllText($f), (New-Object Text.UTF8Encoding $false))
            Remove-Item $f -Force
        }
    }
    Write-Log "$LogName.log" "== exit code $code"
    return $code
}
