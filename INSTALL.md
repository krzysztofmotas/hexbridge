# Installing HexBridge with local test-signing (no VM required)

This installs the driver directly on a real Windows 11 machine using
`testsigning` mode. Read this whole file before running anything.

**`bcdedit /set testsigning on` affects driver-signature verification
system-wide on this machine until reverted** - not just for HexBridge.
It is fully reversible (step 6), but don't skip reverting it once
you're done testing.

If you'd rather not touch your machine's signing policy at all, run
this in an isolated VM instead, or skip straight to real signing (see
`README.md` "Production signing").

All commands below must be run in an **Administrator** PowerShell.

## 0. Build the package

```powershell
driver\dll-shim\build.ps1          # builds RT-USB.dll from RT-USB.def
scripts\build-test-package.ps1     # assembles + signs driver\package\
```

The second script generates a local code-signing certificate the
first time you run it (reused on later runs), and prints its
thumbprint and the path to the exported `.cer`.

## 1. Trust the test certificate (one-time, Administrator)

```powershell
Import-Certificate -FilePath "driver\package\HexBridge-TestSigning.cer" -CertStoreLocation Cert:\LocalMachine\Root
Import-Certificate -FilePath "driver\package\HexBridge-TestSigning.cer" -CertStoreLocation Cert:\LocalMachine\TrustedPublisher
```

## 2. Enable test-signing mode (Administrator, requires reboot)

```powershell
bcdedit /set testsigning on
```

Reboot. After reboot you'll see a "Test Mode" watermark in the
bottom-right corner of the desktop - expected, and your reminder that
this setting is active.

## 3. Install the driver package (Administrator, after reboot)

```powershell
pnputil /add-driver "driver\package\HexBridge-ftdibus.inf" /install
```

If it fails, check `C:\Windows\INF\setupapi.dev.log` for the exact
reason (search for `HexBridge` or `FTDIBUS`).

## 4. Connect the HEX-USB device and verify enumeration

```powershell
Get-PnpDevice | Where-Object { $_.InstanceId -like "USB\VID_0403&PID_FA24*" } |
    Format-Table InstanceId, FriendlyName, Status, Present -AutoSize

Get-PnpDevice | Where-Object { $_.InstanceId -like "USB\VID_0403&PID_FA24*" } |
    Get-PnpDeviceProperty -KeyName DEVPKEY_Device_DriverVersion, DEVPKEY_Device_DriverInfPath, DEVPKEY_Device_ProblemCode
```

Expect `Present = True`, `Status = OK`, `DriverVersion` matching the
CDM package you used (see `driver/redist/README.txt`), and no
`ProblemCode`. If it shows a problem, check the error text in Device
Manager and the `Microsoft-Windows-CodeIntegrity/Operational` log in
Event Viewer.

## 5. Test with the DLL shim + VCDS

1. **Back up** the VCDS install directory's original `RT-USB.dll`
   first (e.g. `Copy-Item RT-USB.dll RT-USB.dll.original-backup`) so
   you can restore it if this doesn't work.
2. Copy `driver\dll-shim\RT-USB.dll` and `driver\redist\ftd2xx.dll`
   into the VCDS install directory, overwriting the original
   `RT-USB.dll` there.
3. Run VCDS and attempt to connect to the HEX-USB device.

To revert: copy `RT-USB.dll.original-backup` back over `RT-USB.dll`.

## 6. When done testing: revert test-signing mode

Leaving testsigning mode on is a standing, system-wide weakening of
driver signature checks - revert it once you're done:

```powershell
bcdedit /set testsigning off
```

Reboot. Optionally also remove the test certificate from the trust
stores (replace the thumbprint with the one your build printed):

```powershell
Get-ChildItem Cert:\LocalMachine\Root, Cert:\LocalMachine\TrustedPublisher |
    Where-Object { $_.Thumbprint -eq "<thumbprint>" } |
    Remove-Item
```

The HexBridge driver package can stay installed (or remove it with
`pnputil /delete-driver <oemXX.inf> /uninstall` - find its name via
`pnputil /enum-drivers`); it simply won't load once testsigning is off,
until it's replaced with a properly Dev Center-signed catalog (see
`README.md` "Production signing").
