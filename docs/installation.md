# Installation and updates

The SDK is distributed as Delphi source. Add the units to your application
and compile them with your Delphi toolchain. It uses `System.JSON` and
`System.Net.HttpClient` from the Delphi runtime library. Native compiler and
runtime compatibility have not been verified for the targets below.

## Platform requirements

| Target | Architecture | Minimum Delphi |
| --- | --- | --- |
| `Win32` | Windows x86 | 10.4 |
| `Win64` | Windows x64 | 10.4 |
| `Linux64` | Linux x64 | 10.4 |
| `OSX64` | macOS Intel x64 | 10.4 |
| `OSXARM64` | macOS ARM64 | 11.0 |
| `Android` | Android ARM32 | 10.4 |
| `Android64` | Android ARM64 | 10.4 |
| `iOSDevice64` | iOS ARM64 device | 10.4 |
| `iOSSimARM64` | iOS ARM64 simulator on a Mac | 11.2 |

These are intended source targets. A source check or Windows test run does
not verify another platform's build, HTTP transport or native runtime.
macOS ARM64 was introduced in
[Delphi 11](https://docwiki.embarcadero.com/RADStudio/Alexandria/en/What%27s_New).
The ARM64 iOS simulator compiler was introduced in
[Delphi 11.2](https://docwiki.embarcadero.com/RADStudio/Florence/en/DCCIOSSIMARM64).
Use an operating-system and SDK version supported by your Delphi release;
see the [vendor's platform status](https://docwiki.embarcadero.com/PlatformStatus/en/Main_Page).

Use a Delphi edition that includes your target compiler; see the
[feature matrix](https://www.embarcadero.com/docs/rad-studio-feature-matrix.pdf).
Configure the target SDK and native environment using the official guides for
[macOS](https://docwiki.embarcadero.com/RADStudio/Florence/en/Working_with_a_Mac_and_a_PC),
[Linux](https://docwiki.embarcadero.com/RADStudio/Florence/en/Linux_Application_Development),
[iOS](https://docwiki.embarcadero.com/RADStudio/Florence/en/IOS_Mobile_Application_Development)
and [Android](https://docwiki.embarcadero.com/RADStudio/Florence/en/Android_Mobile_Application_Development).

## Add the source to a project

Keep the SDK's `src` directory intact and add it to the consuming project's
search path for each target configuration. Use `Raims.Client`, `Raims.Params`
and `Raims.Models` for API calls, `Raims.Core` for options and errors, and
`Raims.Webhooks` when receiving events. Public value constants are in
`Raims.Constants`.

Include the source units directly on all targets. `packages/Raims.dpk` is an
optional Windows runtime-package project. Other targets compile the units
into the consuming application.

The consuming application needs Delphi and its runtime library.

The native HTTP backend also needs the system libraries and certificate trust
store required by the Delphi RTL on that operating system. The SDK does not
bundle those system dependencies; follow the platform setup linked above.

Keep API credentials in a backend service. A desktop or mobile executable
distributed to users cannot protect an embedded API key.

## Update an existing source installation

Replace all SDK units with the same reviewed source revision, remove stale
compiled units from the consuming project's build output, and rebuild every
target. Run your integration checks before replacing the application.
Copying one changed unit into an older SDK can mix incompatible types or
transport behavior.

## Generate and validate

Contributors can check generated source without network access:

```sh
python scripts/generate.py --check
```

The generation check does not compile the units or verify native compatibility.
Build and exercise your integration with the compiler, operating system, and
target configuration used by your application.
