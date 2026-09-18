# HexBridge

Makes Ross-Tech's HEX-USB interface (`USB\VID_0403&PID_FA24`, and the
FA20/FA23/FA25 variants) work with VCDS on Windows 11, without Ross-Tech's
original driver and without disabling any Windows security feature
permanently.

## The problem

Ross-Tech's original `RT-USB64.SYS` / `RT-USB.dll` turned out to be a
renamed, decade-old copy of FTDI's own `FTDIBUS.sys` / `FTD2XX.dll`
(confirmed by static analysis - PDB paths, hardcoded registry keys, and
an identical exported function table). It's signed with a certificate
that Windows 11's driver-signing policy no longer accepts, so the
device gets blocked outright.

FTDI, however, still actively maintains and ships a current,
WHQL-signed version of that exact same driver - it just doesn't know
about Ross-Tech's custom VID/PID. HexBridge is the small amount of
glue needed to point FTDI's real driver at Ross-Tech's hardware ID, so
the two decades-old device variants Ross-Tech shipped keep working with
zero reverse-engineered protocol logic.

## How it works

```
VCDS.exeL -> RT-USB.dll (this repo: a pure export-forwarder shim)
          -> FTD2XX.dll (genuine FTDI file, unmodified)
          -> ftdibus.sys (genuine FTDI file, unmodified, WHQL-signed)
          -> USB -> HEX-USB
```

- **`driver/inf/HexBridge-ftdibus.inf`** - a minimal-diff patch of
  FTDI's own current `ftdibus.inf`, adding the four Ross-Tech hardware
  IDs (`FA20`/`FA23`/`FA24`/`FA25`) to FTDI's driver instead of their
  stock `6001`/`6010`/... set. File names, service name, and install
  structure are otherwise untouched - FTDI's own driver files are
  never renamed (renaming them breaks their signing and isn't
  supported by FTDI).
- **`driver/dll-shim/RT-USB.def`** - VCDS statically links against a
  file named `RT-USB.dll`. This shim keeps that name, but every one of
  its 87 exports is a pure PE forwarder (`FT_Open=FTD2XX.FT_Open`,
  etc.) to the genuine `FTD2XX.dll` - no reimplemented logic, verified
  ordinal-for-ordinal against the original file.

Confirmed working end to end: the driver loads on Windows 11
(`Status: OK`, real driver version, no problem code) and VCDS connects
through the shim to a physical HEX-USB device.

## Repo layout

```
driver/
  inf/          HexBridge-ftdibus.inf - the custom INF (source of truth)
  dll-shim/     RT-USB.def + build.ps1 - builds RT-USB.dll
  redist/       Genuine FTDI files go here (not tracked in git - see redist/README.txt)
  package/      Assembled install package (generated, not tracked)
scripts/
  build-test-package.ps1   Assembles + test-signs driver/package/
INSTALL.md      Step-by-step install runbook (test-signing mode)
```

## Building

1. Get the genuine FTDI CDM driver package from
   `https://ftdichip.com/drivers/vcp-drivers/` and follow
   `driver/redist/README.txt` to place the required files there.
2. Build the shim:
   ```powershell
   driver\dll-shim\build.ps1
   ```

## Installing

See **`INSTALL.md`** for the full step-by-step runbook. Short version:
`scripts\build-test-package.ps1` assembles and test-signs a driver
package, which needs Windows `testsigning` mode enabled to load (fully
reversible, but affects driver-signature checks system-wide while it's
on - read the runbook before running anything).

## Production signing

A `testsigning`-mode install is fine for verifying this works, but
isn't meant to stay on permanently. To get a driver package that loads
with normal Windows security settings, `driver/inf/HexBridge-ftdibus.inf`
plus the genuine FTDI files need to be submitted through the **Windows
Hardware Dev Center** (Microsoft Partner Center - Hardware) for a real
attestation signature. This requires a Partner Center account and
replacing the `Provider`/`MfgName` placeholder in the INF with the
submitting entity's name. See FTDI's AN_101 "Submitting Modified FTDI
Drivers for Windows Hardware Certification" for the vendor-side
requirements of this exact scenario (custom VID/PID on their driver).

## Licensing notes

- FTDI's driver files (`driver/redist/`) are FTDI's own copyrighted,
  freely-redistributable binaries, used here per their license terms
  ("FTDI drivers may be used only in conjunction with products based
  on FTDI parts" - HEX-USB physically contains a genuine FTDI chip).
  They are not committed to this repo; `driver/redist/README.txt`
  documents exactly which version to obtain and how to verify it
  (SHA-256).
- `driver/inf/HexBridge-ftdibus.inf` is a derivative of FTDI's own
  `ftdibus.inf`, modified per FTDI's own documented procedure for
  adding a custom VID/PID (AN_107 section 4.1).
- `driver/dll-shim/` contains no FTDI or Ross-Tech code - it's a
  from-scratch forwarder table built from the *names* in the public
  D2XX API, not from any decompiled or copied implementation.
