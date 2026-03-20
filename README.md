# BlackScreen

BlackScreen is a macOS menu bar app that turns off your MacBook's built-in display without closing the lid. The idea is to max out performance when an external monitor is connected while leaving the laptop open for better heat dissipation.

Note that this was built with heavy assistance from Claude Code. I reviewed to the best of my abilities but proceed with caution.

This has only been tested on a MacBook Pro 16-inch with M3 Pro chip.

This app uses a private macOS API (`CGSConfigureDisplayEnabled`) that is not publicly documented by Apple. It could break in future macOS updates.

If you want to be able to do this and much, much more, consider getting [BetterDisplay](https://github.com/waydabber/BetterDisplay) instead.

## What it does

- Adds a small icon to your menu bar. There is no dock icon.
- Clicking it shows you a dropdown with an option to turn off the built-in display
- Automatically re-enables the built-in display if your external monitor disconnects abruptly
- Re-enables the built-in display when you quit the app

## Install

### Option 1: Download the pre-built app

1. Download `BlackScreen.app.zip` from [Releases](../../releases)
2. Unzip it
3. Double click `BlackScreen.app` to run it. You can optionally move it to your Applications folder along with all your other apps.

> **Gatekeeper warning:** Since the app is not signed with an Apple Developer certificate, macOS will block it on first launch. To bypass this:
> 1. Right-click (or Control-click) on `BlackScreen.app`
> 2. Select **Open** from the context menu
> 3. Click **Open** in the warning dialog
>
> You only need to do this once. Alternatively, run this in a terminal:
> ```
> xattr -cr /path/to/BlackScreen.app
> ```

### Option 2: Build from source using the included build script

Requires Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/nelsonfigueroa/blackscreen.git
cd blackscreen
./build.sh
```

You'll see `BlackScreen.app` created in the directory. Double click it to run. You will not need to get past Gatekeeper like with Option 1 if you build it locally yourself. You can optionally move it to your Applications folder along with all your other apps

### Troubleshooting

If at any point your built-in display remains black even after disconnecting an external monitor, try closing and opening the laptop lid to reset.
