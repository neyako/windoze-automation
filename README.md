# windoze

I review laptops for short-form videos. Brands lend me a machine for a week or two, and every one arrives
the same way: half-updated Windows, trial antivirus, ads in the Start menu, an old graphics driver.
Before I can say anything fair about it, I have to clean it up, install my apps and run the same tests I ran
on the last one.

This repo does all of that from one external SSD. Plug it in, double-click `Setup.cmd`, approve the admin
prompt once, and come back later to a laptop that is clean, fully updated and ready to test.

> Built for borrowed test laptops, not your daily PC. It turns off the firewall and UAC prompts and
> installs my personal app list. Read `config.psd1` before running it on anything you care about.

## What setup does

In order, picking up by itself after every reboot:

1. **Copies the test tools** to `C:\Bench` and puts two shortcuts on the desktop: **CBR23 Bench** and **Battery Test**.
2. **Sets the clock** to Vietnam time (UTC+7). Laptops usually arrive set up with a US region and time zone.
3. **Cleans Windows**: removes ads, suggestions, Bing in search, Copilot, Recall, Widgets and preinstalled junk
   (trial antivirus, Booking.com and so on). Dark mode, file extensions shown, a quieter File Explorer.
   Windows Terminal becomes the default console.
   It never touches power plans or sleep settings, and it keeps the brand's own apps (fan modes, RGB, screen
   control), because those change benchmark results and are part of the review.
4. **Installs runtimes** most apps and games need: .NET, Visual C++, DirectX, Java, Python, Node.
5. **Installs my apps** (browser, chat, password manager, Steam, MSI Afterburner and more) from the list in
   `config.psd1`, and sets up Helium with my extensions and settings (see [Helium](#helium)).
6. **Runs Windows Update** until nothing is left, rebooting as many times as it takes. It also stops Windows
   from restarting by itself while you're signed in.
7. **Installs the newest graphics driver** straight from NVIDIA or AMD, after Windows Update so it can't be
   replaced by an older one. Intel graphics drivers come from Windows Update.
8. **Updates everything else**, including the brand's Microsoft Store apps.
9. **Installs PCMark 10 and DaVinci Resolve** from the SSD. Resolve can't install silently, so its installer
   opens at the end for you to click through.
10. **Turns off startup apps** so every laptop starts its tests from the same quiet state.
11. **Unpins everything** from Start and the taskbar.

At the end it prints a short list of things only you can do: sign-ins, adding the Steam library on the SSD.
If something failed, it's listed there too. The full log is `C:\Bench\setup.log`.

## Testing

Both tests refuse to start while setup is still running or Windows is waiting to restart, because either
one would interrupt the test halfway.

### CBR23 Bench

A 10-minute Cinebench R23 run on all cores, then 10 minutes on one core, with a 2-minute cooldown before each.
Ten minutes is the point: a laptop that scores high for 30 seconds and then throttles shows up here.

While it runs, it records every sensor once a second through HWiNFO. Each run adds one row per test to
the laptop's summary: score, CPU power, temperature and clock speed. It notices by itself whether the laptop
is plugged in or on battery, so run it once each way. When it asks for a note, type the brand's fan or
performance mode (for example "Turbo" or "Balance") so you know later what the numbers mean.

If something on the laptop tries to close Cinebench mid-run, the script answers "No" and notes the time.

### Battery Test

How long the laptop lasts doing normal things: browsing five websites, scrolling Word and Excel files and
watching YouTube, on a loop until it dies. Brightness and volume are set by the script so every laptop is
tested the same way.

Charge to 100%, unplug the SSD (it draws power), open the shortcut and unplug the charger when it asks.
Open the shortcut again after charging to see the result.

### Results

Everything goes to `C:\Bench\results\<laptop name>\`, and is copied to the SSD the next time a test runs with
the SSD plugged in. The SSD also keeps one table per test with every laptop ever tested, ready to compare.

Game benchmarks are by hand: MSI Afterburner is installed and the games live on the SSD.

## The SSD

```
X:\windoze\                    this repo
  tools\                       installers too big for git (PCMark, Resolve), see tools\README.md
  games\SteamLibrary\          3DMark and games. Steam > Settings > Storage > add this folder
  results\                     every laptop's results
```

The SSD is exFAT so it also works on a Mac.

## Remote help over SSH

If `assets\devbox.pub` exists, setup turns on SSH with that key only (no passwords) and prints the laptop's
address at the end. That lets me check on a stuck setup or a test from another computer. The key is not in
git; put your own public key there if you want this, or leave it out and setup skips it.

## Helium

Helium has no sync, so `helium\` is the backup of the Helium on my Mac: the extension list, flags, a few
settings (layout, theme, pinned extensions) and each extension's own data, Tampermonkey scripts included.
Setup force-installs the extensions by policy and puts the rest in place before Helium first starts, so
Helium says it is managed and the extensions can't be removed on the laptop.

To update it, in a clone of this repo on the Mac: quit Helium, run `python3 helium/backup.py`, check
`git diff`, commit. The repo is public, so it leaves out 1Password's data and the user IDs extensions keep
(SponsorBlock, Return YouTube Dislike, and FB Purity's settings, which are named after the Facebook account).
If one of those IDs also shows up somewhere else, it stops without writing anything.

The battery test still uses Brave with a clean profile, so its results stay comparable with older laptops.

## Tweaking

Everything personal lives in `config.psd1`: time zone, apps, what gets removed, which startup apps stay on,
and the battery test's websites and videos. `tests\Test-Config.ps1` checks it for mistakes.

The empty Start layout in `assets\start2.bin` is from [Win11Debloat](https://github.com/Raphire/Win11Debloat) (MIT).
