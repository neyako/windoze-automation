@{
    TimeZone = 'SE Asia Standard Time'   # UTC+7, Bangkok/Hanoi/Jakarta

    # winget IDs, installed in this order. Runtimes first so apps can use them.
    Runtimes = @(
        'Microsoft.PowerShell'
        'Python.Python.3.14'
        'astral-sh.uv'
        'OpenJS.NodeJS.LTS'
        'EclipseAdoptium.Temurin.25.JDK'
        'Microsoft.DotNet.DesktopRuntime.3_1'
        'Microsoft.DotNet.DesktopRuntime.5'
        'Microsoft.DotNet.DesktopRuntime.6'
        'Microsoft.DotNet.DesktopRuntime.7'
        'Microsoft.DotNet.DesktopRuntime.8'
        'Microsoft.DotNet.DesktopRuntime.9'
        'Microsoft.DotNet.DesktopRuntime.10'
        'Microsoft.VCRedist.2005.x86'
        'Microsoft.VCRedist.2005.x64'
        'Microsoft.VCRedist.2008.x86'
        'Microsoft.VCRedist.2008.x64'
        'Microsoft.VCRedist.2010.x86'
        'Microsoft.VCRedist.2010.x64'
        'Microsoft.VCRedist.2012.x86'
        'Microsoft.VCRedist.2012.x64'
        'Microsoft.VCRedist.2013.x86'
        'Microsoft.VCRedist.2013.x64'
        'Microsoft.VCRedist.2015+.x86'
        'Microsoft.VCRedist.2015+.x64'
        'Microsoft.DirectX'
    )

    Apps = @(
        'Microsoft.WindowsTerminal'
        'Brave.Brave'
        'AgileBits.1Password'
        'Telegram.TelegramDesktop'
        'Vencord.Vesktop'
        'LocalSend.LocalSend'
        'Tailscale.Tailscale'
        'M2Team.NanaZip'
        'shinchiro.mpv'
        'DuongDieuPhap.ImageGlass'
        'ShareX.ShareX'
        'Notepad++.Notepad++'
        'Git.Git'
        'Microsoft.PowerToys'
        'T3Tools.T3Code'
        'Valve.Steam'
        'PrismLauncher.PrismLauncher'
        'CrystalDewWorld.CrystalDiskMark'
        'Guru3D.Afterburner'
        'Guru3D.RTSS'
    )

    # Zips extracted to Program Files with a Start menu shortcut. EVKey replaces its release file in place,
    # so winget's pinned hash keeps breaking.
    PortableZips = @(
        @{ Name = 'EVKey'; Url = 'https://github.com/lamquangminh/EVKey/releases/download/Release/EVKey.zip'; Exe = 'x64\EVKey64.exe' }
    )

    # Latest release .msi from GitHub, for apps not on winget.
    GitHubMsi = @(
        @{ Repo = 'rustdesk/rustdesk'; Asset = 'x86_64\.msi$' }
    )

    # Installers kept on the SSD under tools\installers. Path is a wildcard; newest match wins.
    SsdInstallers = @(
        # Resolve 21's Qt installer has no silent mode: it is opened at the end for you to click through.
        @{ Name = 'DaVinci Resolve'; Path = 'DaVinci_Resolve*\Install Resolve*.exe'; Interactive = $true }
        @{ Name = 'PCMark 10';       Path = 'PCMark10*\pcmark10-setup.exe';          Args = '/install /quiet' }
    )

    # AppX packages removed by debloat (wildcards). Anything not listed stays,
    # so vendor apps (Armoury Crate, Legion Space, Vantage, MSI Center, OMEN...) are never touched.
    RemoveAppx = @(
        'Microsoft.549981C3F5F10'            # Cortana
        'Microsoft.BingNews'
        'Microsoft.BingWeather'
        'Microsoft.BingSearch'
        'Microsoft.Copilot'
        'Microsoft.Windows.Ai.Copilot.Provider'
        'Microsoft.GetHelp'
        'Microsoft.Getstarted'
        'Microsoft.MicrosoftOfficeHub'       # Microsoft 365 app, not desktop Office (the battery test needs that)
        'Microsoft.MicrosoftSolitaireCollection'
        'Microsoft.MixedReality.Portal'
        'Microsoft.News'
        'Microsoft.OutlookForWindows'
        'Microsoft.People'
        'Microsoft.PowerAutomateDesktop'
        'Microsoft.SkypeApp'
        'Microsoft.Todos'
        'Microsoft.Windows.DevHome'
        'Microsoft.WindowsFeedbackHub'
        'Microsoft.WindowsMaps'
        'Microsoft.windowscommunicationsapps'
        'Microsoft.ZuneVideo'
        'Microsoft.ZuneMusic'                # Media Player, replaced by mpv
        'Microsoft.Windows.Photos'           # replaced by ImageGlass
        'Microsoft.ScreenSketch'             # Snipping Tool, replaced by ShareX
        'Microsoft.YourPhone'                # Phone Link
        'Microsoft.MicrosoftStickyNotes'
        'MicrosoftCorporationII.QuickAssist'
        'MicrosoftWindows.CrossDevice'       # Phone Link helper
        'Microsoft.6365217CE6EB4'            # Microsoft Defender (the consumer app, not Windows Security)
        'aimgr'                              # Local AI Manager for Microsoft 365
        'Microsoft.MicrosoftJournal'
        'Microsoft.Whiteboard'
        'Microsoft.MixedRealityLink'
        'Microsoft.Edge.GameAssist'
        'MicrosoftWindows.Client.WebExperience'   # Widgets
        'MicrosoftCorporationII.MicrosoftFamily'
        'MicrosoftTeams'
        'MSTeams'
        'Clipchamp.Clipchamp'
        '7EE7776C.LinkedInforWindows'
        '*Disney*'
        '*Netflix*'
        '*Spotify*'
        '*TikTok*'
        '*Instagram*'
        '*Facebook*'
        '*Twitter*'
        '*CandyCrush*'
        'king.com.*'
        '*AmazonVideo*'
        '*PrimeVideo*'
        'Amazon.com.Amazon'
        '*Booking*'
        '*ExpressVPN*'
        '*McAfee*'
        '*Norton*'
        '*WildTangent*'
        '*Dropbox*'
        '*Hulu*'
        '*PicsArt*'
        '*Duolingo*'
        '*AdobeExpress*'
        '*PhotoshopExpress*'
    )

    # Win32 apps removed with `winget uninstall --name` (display name match).
    RemoveWin32 = @(
        'Microsoft OneDrive'
        'McAfee'
        'Norton'
        'ExpressVPN'
        'WildTangent'
        'Booking.com'
    )

    # Everything else in Task Manager > Startup apps is disabled at the end of setup (wildcards on name or command).
    StartupKeep = @(
        '*Wallpaper*'
    )

    # Copied verbatim from brave://flags on the MacBook.
    BraveFlags = @(
        'brave-rewards-allow-self-custody-providers@2'
        'brave-rewards-allow-unsupported-wallet-providers@2'
        'brave-rewards-animated-background@2'
        'brave-rewards-platform-creator-detection@2'
        'brave-rewards-verbose-logging@2'
        'brave-show-strict-fingerprinting-mode@1'
        'brave-wallet-bitcoin@2'
        'brave-wallet-cardano@2'
        'brave-wallet-zcash@4'
        'enable-force-dark@1'
    )

    Battery = @{
        Brightness   = 75
        Sites        = @(
            'https://www.engadget.com/'
            'https://www.theverge.com/'
            'https://en.wikipedia.org/wiki/Laptop'
            'https://www.bbc.com/news'
            'https://github.com/trending'
        )
        SiteSeconds  = 60
        OfficeSeconds = 120
        Videos       = @(
            'https://www.youtube.com/watch?v=MbXLt7OwEXI'
            'https://www.youtube.com/watch?v=w1ucZCmvO5c'
        )
        VideoMinutes = 20
    }
}
