# Using Claude Opus 4.6 bringing Notational Velocity back to life on modern macOS

![Notational Velocity running on modern macOS](https://github.com/and/nv4/raw/master/screenshot.png)

[Notational Velocity](https://notational.net/) was one of those rare applications that did one thing perfectly. A lightning-fast, keyboard-driven note-taking app for macOS, it let you search and create notes in a single unified interface. No mouse needed. No friction. Just thoughts flowing into text.

Then it stopped working.

The last commit to the open-source project landed in 2021, and somewhere between macOS updates and Xcode releases, the app wouldn't build anymore. The codebase, written in Objective-C with roots going back to the Mac OS X 10.4 Tiger era, had accumulated just enough technical debt that modern development tools rejected it.

## What Claude Found

I forked the repository and asked Claude to investigate why it wouldn't build, initially through the mobile app. It connected to the GitHub repository, ran `xcodebuild`, parsed through the compilation output, and identified three blockers:

### 1. Incompatible Function Pointer Types in LinkingEditor.m

It found code that dynamically swaps cursor implementations for the I-beam cursor (to show a white cursor on dark backgrounds). The code used runtime manipulation via `method_setImplementation()`, but assigned function pointers to `IMP` types without proper casting:

```objective-c
// Line 980 - First error identified
method_setImplementation(defaultIBeamCursorMethod,
    shouldBeWhite ? whiteIBeamCursorIMP : defaultIBeamCursorIMP);
```

Modern Clang's stricter type checking rejected this. The error: "incompatible function pointer types passing 'id (*)(Class, SEL)' to parameter of type 'IMP' (aka 'void (*)(void)')".

### 2. Incompatible Function Pointer Types in GlobalPrefs.m

It caught a similar issue where `methodForSelector:` returns an `IMP` (essentially a `void*` function pointer) but was being assigned to a typed function pointer without an explicit cast:

```objective-c
// Line 102 - Second error found
runCallbacksIMP = [self methodForSelector:@selector(notifyCallbacksForSelector:excludingSender:)];
```

The variable `runCallbacksIMP` was declared as `id (*)(GlobalPrefs*, SEL, SEL, id)`, a specific function signature, but `methodForSelector:` returns the generic `IMP` type.

### 3. Unknown Linker Option

It traced through the Xcode project settings and found `-whatsloaded` in `OTHER_LDFLAGS`, a legacy linker flag that was removed in modern versions of the macOS linker. The linker simply refused to link with an "unknown options" error.

## How Claude Fixed It

Once the issues were identified, it made surgical, minimal fixes: just enough to satisfy modern tooling without rewriting legacy code.

### Fix 1: Add Explicit Type Cast in LinkingEditor.m

```objective-c
// Added explicit cast to IMP
method_setImplementation(defaultIBeamCursorMethod,
    (IMP)(shouldBeWhite ? whiteIBeamCursorIMP : defaultIBeamCursorIMP));
```

The logic remained unchanged. We simply made the implicit type conversion explicit.

### Fix 2: Add Explicit Type Cast in GlobalPrefs.m

```objective-c
// Cast the IMP back to the specific function pointer type
runCallbacksIMP = (id (*)(GlobalPrefs*, SEL, SEL, id))[self methodForSelector:@selector(notifyCallbacksForSelector:excludingSender:)];
```

Again, no behavioral change — just satisfying the type system.

### Fix 3: Remove Deprecated Linker Flag

Deleted one line from the Xcode project configuration:
```
OTHER_LDFLAGS = (
    "-whatsloaded",  // ← Deleted this
    "-weak_framework",
    PDFKit,
    ...
);
```

That's it. **Two type casts and one deleted line.** The app built successfully on Xcode 16 running on macOS Sequoia.

After the code was fixed through the mobile app, I cloned the repository locally to my Mac and ran it in Xcode to verify everything worked. The entire process, from initial investigation on mobile to a working build on my machine, happened in one morning session with [Claude Opus 4.6](https://www.anthropic.com/claude). The subsequent packaging and release management was handled through [Claude Code](https://docs.anthropic.com/en/docs/build-with-claude/claude-code) in the terminal.

What impressed me most: it never suggested rewriting the entire thing in Swift or "modernizing" the architecture. It understood the goal was minimal intervention: just enough to build, nothing more. The AI's strength wasn't in replacing human judgment about what to preserve; it was in executing the tedious work of tracking down compiler errors and making type-safe fixes.

## What's Still There

The codebase still generates hundreds of deprecation warnings:

- **Carbon File Manager APIs** - The app uses `FSRef`, `FSSpec`, `FSCatalogInfo`, and other Carbon-era file system calls throughout. These are deprecated but continue to work on both Intel and Apple Silicon Macs through macOS 15. Replacing them would require rewriting ~30 files of file management code.

- **Legacy AppKit APIs** - `NSRunAlertPanel`, `NSRunCriticalAlertPanel`, old pasteboard types (`NSStringPboardType`), legacy control states (`NSOnState`, `NSOffState`). All deprecated, all still functional through OS compatibility shims.

- **Ancient OpenSSL dependencies** - The app links against OpenSSL for AES-256 encryption and MD5 hashing. It finds the libraries via Homebrew paths (`/usr/local/opt/openssl/lib` and `/opt/homebrew/opt/openssl/lib`). A proper fix would migrate to Apple's CommonCrypto framework, but that's a larger refactor.

These generate compiler warnings but don't prevent compilation or execution. Modern macOS maintains backward compatibility for these APIs, even as it deprecates them.

## The Distribution Problem

Building the app was only half the battle. Distributing it revealed a second issue: **macOS Gatekeeper**.

When users download the app and try to open it, macOS blocks it with a security warning:

> "Notational Velocity" cannot be opened because Apple cannot verify it is free of malware.

This is expected behavior for unsigned apps. The fixes:

### For Users: System Settings Workaround

1. Download the DMG and drag the app to Applications
2. Try to open it (it will be blocked)
3. Go to **System Settings → Privacy & Security**
4. Scroll to "Security" and click **"Open Anyway"**
5. Confirm in the dialog

Alternatively, right-click the app and select "Open" — this bypasses Gatekeeper on the first launch.

### Upstream Contribution

I've submitted a [pull request](https://github.com/scrod/nv/pull/398) with these fixes to the original Notational Velocity repository. If the original author merges it, users will be able to get signed releases directly from the official project.

If the PR isn't merged, I'll distribute properly signed and notarized releases from my fork once my Apple Developer account is approved (currently pending). The Developer account enables:
1. Code signing with a Developer ID certificate
2. Notarization via Apple's automated malware scan
3. Distribution without security warnings

## The Result

The modernized build is available now:

**Repository:** [github.com/and/nv4](https://github.com/and/nv4)
**Release:** [v1.0 - Modern macOS Build](https://github.com/and/nv4/releases/tag/v1.0)

The release includes:
- DMG installer ready to run on macOS Sequoia (and earlier versions)
- Full compatibility with Apple Silicon and Intel Macs
- All original features intact

## Why It Matters

In an era of Electron apps, subscription note services, and feature-bloated productivity suites, Notational Velocity remains a masterclass in focused software design. It:

- Launches instantly (< 0.5 seconds cold start)
- Searches instantly (incremental search as you type)
- Stays out of your way (no chrome, no sidebars, no "experiences")
- Stores notes as plain text files (future-proof, greppable, version-controllable)
- Works entirely from the keyboard (mouse optional)

The codebase is a time capsule of Mac development practices from 2006-2012: Carbon APIs, FSRef file management, hand-rolled crypto, minimal dependencies. It predates ARC, blocks, Grand Central Dispatch, and most of modern Cocoa.

But it's also a reminder that software doesn't have to be constantly rewritten to stay valuable. Sometimes the right intervention is the smallest one: just enough modern compatibility to keep running on current hardware, without sacrificing the characteristics that made it good in the first place.

Some software deserves to keep working.

---

*If you're interested in helping maintain or extend this project, contributions are welcome at [github.com/and/nv4](https://github.com/and/nv4). Special areas for improvement: migrating to CommonCrypto, replacing Carbon File Manager calls with modern equivalents, and adding proper code signing infrastructure.*
