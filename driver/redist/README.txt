This folder holds the UNMODIFIED, original files from the official
FTDI CDM (Combined Driver Model) package.

STATUS: DONE. Files obtained from CDM v2.12.36.20 (WHQL Certified,
released 2024-10-28), downloaded from
https://ftdichip.com/drivers/vcp-drivers/ as
CDM-v2.12.36.20-WHQL-Certified.zip (a plain zip of the raw driver
files, not a setup executable). The archive is kept at
tools/CDM-v2.12.36.20-WHQL-Certified.zip, extracted into
tools/cdm-extracted/.

Files here (copied verbatim, not renamed - see SHA256SUMS.txt):

    ftdibus.sys     (from amd64/) - kernel-mode driver, 64-bit
    ftd2xx64.dll    (from amd64/) - D2XX API, 64-bit
    ftbusui.dll     (from amd64/) - optional Device Manager property page
    FTLang.dll      (from amd64/) - language resources for ftbusui.dll
    ftd2xx.dll      (from i386/)  - D2XX API, 32-bit - the file
                                     driver/dll-shim/RT-USB.dll forwards to
    ftd2xx.h        (package root) - official D2XX API header, kept for
                                      reference (not used in the build,
                                      since RT-USB.dll is pure forwarders
                                      with no C code)

Signature check performed (Get-AuthenticodeSignature): all three
binaries (ftdibus.sys, ftd2xx.dll, ftd2xx64.dll) are signed by
"CN=Microsoft Windows Hardware Compatibility Publisher" - genuine,
WHQL-signed Microsoft driver files.

Do NOT rename or modify these files (see FTDI AN_107 section 10 -
renaming driver files invalidates certification and is not supported
by FTDI).

driver/inf/HexBridge-ftdibus.inf references these files by their
original names via the [SourceDisksFiles.amd64] / Copy / Copy2 / Copy3
sections.
