# Builds RT-USB.dll (32-bit) purely from RT-USB.def.
#
# IMPORTANT: this DLL contains no code of its own. All 87 exports are
# pure PE export forwarders (forward RVA) to the real, unmodified,
# officially-signed FTD2XX.dll (32-bit), which must be present in the
# same directory as RT-USB.dll at runtime (standard Windows DLL search
# order).
#
# Why no .obj/.c file: passing any object file to link.exe makes the
# linker try to resolve .def entries as plain symbols from that object
# (LNK2001), instead of recognizing the "Name=Module.Name" forwarder
# syntax in EXPORTS. Verified empirically: /DLL /NOENTRY /DEF:... with
# no .obj files works correctly and produces real forward RVAs
# (confirmed via dumpbin /exports).

$ErrorActionPreference = "Stop"

$vcTools = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.42.34433"
$link = Join-Path $vcTools "bin\Hostx64\x86\link.exe"

if (-not (Test-Path $link)) { throw "link.exe not found at $link" }

$here = $PSScriptRoot
Push-Location $here
try {
    & $link /nologo /DLL /NOENTRY /MACHINE:X86 /DEF:RT-USB.def /OUT:RT-USB.dll
    if ($LASTEXITCODE -ne 0) { throw "link.exe failed" }

    Write-Output "Built: $here\RT-USB.dll"
} finally {
    Pop-Location
}
