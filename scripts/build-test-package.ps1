# Assembles driver/package/ (a self-signed, test-signing-only install
# package) from driver/inf/ + driver/redist/, generates a local code
# signing certificate if one doesn't already exist, and signs the
# resulting catalog.
#
# This package only loads on a machine with `bcdedit /set testsigning
# on` (see tests/INSTALL.md). It is NOT a substitute for real signing -
# see README.md "Production signing" for that.
#
# Requires driver/redist/ to already contain the genuine FTDI files
# (see driver/redist/README.txt) and driver/dll-shim/RT-USB.dll to
# already be built (see driver/dll-shim/build.ps1).

$ErrorActionPreference = "Stop"

$repoRoot  = Split-Path -Parent $PSScriptRoot
$infDir    = Join-Path $repoRoot "driver\inf"
$redistDir = Join-Path $repoRoot "driver\redist"
$pkgDir    = Join-Path $repoRoot "driver\package"

$requiredRedistFiles = @("ftdibus.sys", "ftbusui.dll", "ftd2xx64.dll", "ftd2xx.dll", "FTLang.dll")
foreach ($f in $requiredRedistFiles) {
    if (-not (Test-Path (Join-Path $redistDir $f))) {
        throw "Missing $redistDir\$f - see driver\redist\README.txt to obtain the genuine FTDI CDM files"
    }
}

New-Item -ItemType Directory -Force -Path $pkgDir | Out-Null
Copy-Item (Join-Path $infDir "HexBridge-ftdibus.inf") $pkgDir -Force
foreach ($f in $requiredRedistFiles) {
    Copy-Item (Join-Path $redistDir $f) $pkgDir -Force
}

# Reuse an existing local test cert if one was already generated,
# otherwise create one (valid 3 years).
$certSubject = "CN=HexBridge Test Signing"
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert |
    Where-Object { $_.Subject -eq $certSubject } |
    Select-Object -First 1

if (-not $cert) {
    Write-Output "No existing test certificate found, generating one..."
    $cert = New-SelfSignedCertificate -Type CodeSigningCert `
        -Subject $certSubject `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -NotAfter (Get-Date).AddYears(3) `
        -KeyUsage DigitalSignature `
        -FriendlyName "HexBridge Test Signing (local, testsigning-mode only)"
}

Write-Output "Using certificate thumbprint: $($cert.Thumbprint)"

$cerPath = Join-Path $pkgDir "HexBridge-TestSigning.cer"
Export-Certificate -Cert $cert -FilePath $cerPath | Out-Null

$catPath = Join-Path $pkgDir "HexBridge-ftdibus.cat"
if (Test-Path $catPath) { Remove-Item $catPath }
New-FileCatalog -Path $pkgDir -CatalogFilePath $catPath -CatalogVersion 2.0 | Out-Null

$signtoolCandidates = Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\signtool.exe" -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending
if (-not $signtoolCandidates) { throw "signtool.exe not found under Windows Kits 10 - install the Windows SDK" }
$signtool = $signtoolCandidates[0].FullName

& $signtool sign /sha1 $cert.Thumbprint /fd SHA256 /t http://timestamp.digicert.com $catPath
if ($LASTEXITCODE -ne 0) { throw "signtool sign failed" }

Write-Output ""
Write-Output "Package ready: $pkgDir"
Write-Output "Certificate to trust (see tests/INSTALL.md step 1): $cerPath"
Write-Output "Thumbprint: $($cert.Thumbprint)"
