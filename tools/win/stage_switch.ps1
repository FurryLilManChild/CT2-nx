# Puts the game data next to the Switch build in out\sd\switch\<game>, ready to copy to the SD
# card: the disc (CHD, or GDI and tracks) into disc\, 1ST_READ.BIN, and the memory card into
# save\. The NRO and <game>.toml are put there by Claude's Switch build.
#   powershell -ExecutionPolicy Bypass -File tools\win\stage_switch.ps1
param([string]$Game = 'crazytaxi2')
. "$PSScriptRoot\common.ps1"
$Dest = Join-Path $Root "out\sd\switch\$GameId"
New-Item -ItemType Directory -Force -Path (Join-Path $Dest 'disc'), (Join-Path $Dest 'save') | Out-Null

# This game's own dump: the image the toml names.
$image = ((Get-Content $GameToml | Where-Object { $_ -match '^image = "' }) -replace '^image = ".*/([^/"]+)".*$', '$1')
$src = Join-Path $Root "assets\$image"
if (-not (Test-Path -LiteralPath $src)) { throw "No $image in assets\. Tell Claude." }
$disc = @(Get-Item -LiteralPath $src)
if ($src -like '*.gdi') {
    $disc += @(Get-ChildItem (Join-Path $Root 'assets') -File | Where-Object { $_.Extension -in '.bin', '.raw' })
}
foreach ($f in $disc) {
    $to = Join-Path (Join-Path $Dest 'disc') $f.Name
    # Copy unless an identical-size copy is already there (a cut-off earlier copy is replaced).
    if (-not (Test-Path -LiteralPath $to) -or (Get-Item -LiteralPath $to).Length -ne $f.Length) {
        Write-Host "copying $($f.Name) ($([math]::Round($f.Length / 1MB)) MB) ..."
        Copy-Item -LiteralPath $f.FullName -Destination $to -Force
    }
}
Copy-Item -LiteralPath (Join-Path $Root "games\$GameId\extracted\fs\1ST_READ.BIN") -Destination $Dest -Force
if ((Test-Path $VmuFile) -and -not (Test-Path (Join-Path $Dest 'save\vmu_A1.bin'))) {
    Copy-Item -LiteralPath $VmuFile -Destination (Join-Path $Dest 'save\vmu_A1.bin') -Force
}

$need = @("$GameId.nro", "$GameId.toml", '1ST_READ.BIN')
$missing = @($need | Where-Object { -not (Test-Path (Join-Path $Dest $_)) })
Write-Host ''
Get-ChildItem $Dest -Recurse -File | ForEach-Object {
    Write-Host ("  {0,-60} {1,12:N0} bytes" -f $_.FullName.Substring($Dest.Length + 1), $_.Length)
}
if ($missing.Count) {
    Write-Host "Not there yet (Claude's build puts them here): $($missing -join ', ')"
} else {
    Write-Host ''
    Write-Host "Ready. Copy the folder $Dest to the SD card as sdmc:\switch\$GameId\"
}
