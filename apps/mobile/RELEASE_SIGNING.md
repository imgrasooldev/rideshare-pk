# Android release signing

## Why this exists

Every Android app is signed with a key. Android refuses to install an update
whose signing key differs from the installed version, and Google Play
permanently binds your app listing to the key of its first upload.

Before this setup, release builds were signed with the **debug key**. Debug
keys are generated per-machine, so:

- an APK built on one laptop would not install over one built on another —
  it failed with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, and the only way
  through was to uninstall, **wiping the tester's app data**;
- the APK could never be published to Play at all.

Now all release builds use one shared upload key.

## ⚠️ Back up the keystore

**If you lose the keystore or its password, you can never publish an update to
an already-published app.** There is no recovery process — you would have to
ship a brand-new listing and every existing user would have to reinstall.

Store both in a password manager or an encrypted backup:

| Item | Location on the build machine |
| --- | --- |
| Keystore | `D:\claude_project\.secrets\rideshare-upload.jks` |
| Password | `D:\claude_project\.secrets\keystore-password.txt` |

Neither is in git, and both are covered by `.gitignore`. Keep it that way — a
keystore in a public repo is a compromised keystore.

Current certificate (verify a build matches this before shipping):

```
CN=Rideshare PK, OU=Mobile, O=Rideshare PK, L=Lahore, C=PK
SHA-256: 3D:A7:97:79:1C:1E:B4:F4:4D:ED:50:06:DA:BF:C4:69:
         5C:0C:99:EA:DE:13:F7:69:3F:DB:FB:19:74:3F:C0:65
```

## Setting up another machine

Copy the keystore across **out of band** (encrypted drive, password manager
attachment — not email or chat), then create `apps/mobile/android/key.properties`:

```properties
storeFile=/absolute/path/to/rideshare-upload.jks
storePassword=<password>
keyAlias=upload
keyPassword=<password>
```

`key.properties` is git-ignored. Without it the build still works but falls
back to debug signing — see below.

## The debug fallback

`android/app/build.gradle.kts` only registers the release signing config when
`key.properties` exists. A clone without the keystore still builds, so CI and
new contributors aren't blocked.

That fallback is a convenience, not a shipping path. **Never distribute an APK
built without `key.properties`** — it carries a machine-local debug key and
recreates the exact problem this setup solves. Check before shipping:

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

If the SHA-256 doesn't match the fingerprint above, the build is debug-signed.

## Building a release

```bash
flutter build apk --release
```

For Play, prefer an App Bundle — Play then generates optimised per-device APKs:

```bash
flutter build appbundle --release
```

## Code shrinking

Release builds run R8 (`isMinifyEnabled` + `isShrinkResources`). Keep rules
live in `android/app/proguard-rules.pro`, covering Flutter, Firebase
Messaging, and Play Core.

R8 failures usually appear at **runtime**, not build time, as
`ClassNotFoundException` or a screen that renders blank. Unit tests will not
catch them. After changing dependencies or keep rules, install the release
build on a real device and exercise login, search, and booking before shipping.
