<#
Script:      Remediation_RebootReminder.ps1
Author:      Daniel Fraubaum
Blog:        https://headsinthecloud.blog
Version:     1.1
Date:        2026-11-18
Description: Intune Remediation script (run as SYSTEM, 64-bit).
             1. Registers a one-time SYSTEM task that enforces the reboot after $CountdownMinutes.
             2. Deploys a modern WPF popup (bottom right, light/dark aware, live countdown) and starts it
                in every interactive user session via a transient scheduled task (BUILTIN\Users).
             3. If nobody is signed in, reboots after $NoUserRebootDelaySeconds instead.
             The reboot is enforced by SYSTEM, closing or killing the popup does not stop it.
             Detection removes all transient tasks and state after the reboot.
#>

# ==========================================================================
# Parameters
# ==========================================================================

# Must match the value in Detection_RebootReminder.ps1
$MaxUptimeDays = 7

# Countdown until the enforced reboot
$CountdownMinutes = 120

# "Remind me later" hides the popup for this long
$SnoozeMinutes = 30

# During the last X minutes the popup can no longer be hidden
$FinalPhaseMinutes = 15

# No interactive session found: reboot after this delay instead of waiting for the countdown
$RebootImmediatelyIfNoUser = $true
$NoUserRebootDelaySeconds = 300

# Fast Startup keeps LastBootUpTime alive across shutdowns, so "shut down every evening" never resets the uptime
$DisableFastStartup = $true

# Branding and texts ({0} = uptime days in MessageText, {0} = deadline time in HintText)
$CompanyName = "headsinthecloud.blog"
$AccentColor = "#0078D4"
$FinalAccentColor = "#C42B1C"
$TitleText = "Restart required"
$MessageText = "Your device has not been restarted for {0} days. Please save your work and restart so updates and security settings can take effect."
$CountdownLabelText = "Automatic restart in"
$HintText = "Your device will restart automatically at {0} at the latest."
$ButtonNowText = "Restart now"
$ButtonLaterText = "Remind me later"
$RestartingText = "Your device is restarting now. Please save your work immediately."
$ShutdownComment = "Scheduled maintenance restart by IT."

# Testing only: fake uptime in days (e.g. 10). Set to $null for production
$TestUptimeDays = $null

# Used for registry key, ProgramData folder and Task Scheduler folder
$OrgPrefix = "headsinthecloud.blog"
$BasePath = "$env:ProgramData\$OrgPrefix\RebootReminder"
$PopupFile = "$BasePath\RebootReminderPopup.ps1"
$RegPath = "HKLM:\SOFTWARE\$OrgPrefix\RebootReminder"
$TaskPath = "\$OrgPrefix\"
$PopupTaskName = "RebootReminder-Popup"
$RebootTaskName = "RebootReminder-EnforcedReboot"
$LogFile = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\RebootReminder.log"

# ==========================================================================
# Popup (runs in user context, written to disk by this script)
# ==========================================================================

$PopupScript = @'
<#
Script:      RebootReminderPopup.ps1
Author:      Daniel Fraubaum
Version:     1.0
Date:        2026-11-18
Description: WPF reboot reminder, deployed and started by Remediation_RebootReminder.ps1.
             Reads all settings from HKLM, the countdown is based on wall clock time (sleep safe).
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$RegPath
)

# ==========================================================================
# Logic
# ==========================================================================

$LogFile = "$env:TEMP\RebootReminderPopup.log"
function Write-PopupLog {
    param ([string]$Message)
    try { Add-Content -Path $LogFile -Value "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") $Message" -Encoding UTF8 } catch { }
}

# Step 1: One instance per session
$Mutex = New-Object System.Threading.Mutex($false, "Local\RebootReminderPopup")
if (-not $Mutex.WaitOne(0)) { exit 0 }

# Step 2: Read configuration and validate the schedule
$Config = Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue
if (-not $Config -or -not $Config.DeadlineUtcTicks) { exit 0 }
$Deadline = ([datetime]::new([int64]$Config.DeadlineUtcTicks, [DateTimeKind]::Utc)).ToLocalTime()
$ScheduledAt = ([datetime]::new([int64]$Config.ScheduledAtUtcTicks, [DateTimeKind]::Utc)).ToLocalTime()
$LastBoot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
if ($LastBoot -gt $ScheduledAt -or (Get-Date) -ge $Deadline) { exit 0 }
$TotalSeconds = [math]::Max(1, ($Deadline - $ScheduledAt).TotalSeconds)
Write-PopupLog "Popup started for $env:USERNAME, deadline $Deadline"

# Step 3: Theme (follows the Windows app theme)
$ThemeKey = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -ErrorAction SilentlyContinue
$IsLight = $ThemeKey.AppsUseLightTheme -eq 1
if ($IsLight) {
    $Palette = @{ Card = "#F7FBFBFB"; Stroke = "#1A000000"; Text = "#E6000000"; Secondary = "#99000000"; Panel = "#0A000000"; Track = "#1A000000"; SecondaryButton = "#0F000000" }
}
else {
    $Palette = @{ Card = "#F2202020"; Stroke = "#33FFFFFF"; Text = "#FFFFFFFF"; Secondary = "#B3FFFFFF"; Panel = "#14FFFFFF"; Track = "#26FFFFFF"; SecondaryButton = "#1FFFFFFF" }
}

# Step 4: Build the window
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

[xml]$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="False" ShowActivated="False" ResizeMode="NoResize"
        Width="452" SizeToContent="Height" FontFamily="Segoe UI Variable Text, Segoe UI">
  <Window.Resources>
    <Style x:Key="PillButton" TargetType="Button">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bd" CornerRadius="6" Background="{TemplateBinding Background}" Padding="16,10">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bd" Property="Opacity" Value="0.88"/></Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="Bd" Property="Opacity" Value="0.72"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="Bd" Property="Opacity" Value="0.45"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="GhostButton" TargetType="Button">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bd" CornerRadius="4" Background="Transparent" Width="28" Height="28">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bd" Property="Background" Value="#22808080"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>
  <Grid Margin="16">
    <Border x:Name="Card" CornerRadius="12" BorderThickness="1" Padding="20" Opacity="0">
      <Border.Effect>
        <DropShadowEffect BlurRadius="28" ShadowDepth="6" Direction="270" Opacity="0.35" Color="Black"/>
      </Border.Effect>
      <Border.RenderTransform>
        <TranslateTransform x:Name="SlideTransform" Y="24"/>
      </Border.RenderTransform>
      <StackPanel>
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <Grid Width="40" Height="40" VerticalAlignment="Center">
            <Ellipse x:Name="IconCircle"/>
            <TextBlock x:Name="IconGlyph" Text="&#xE72C;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="18"
                       Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Grid>
          <StackPanel Grid.Column="1" Margin="14,0,8,0" VerticalAlignment="Center">
            <TextBlock x:Name="TitleBlock" FontSize="16" FontWeight="SemiBold" FontFamily="Segoe UI Variable Display, Segoe UI"/>
            <TextBlock x:Name="CompanyBlock" FontSize="12" Margin="0,2,0,0"/>
          </StackPanel>
          <Button x:Name="CloseButton" Grid.Column="2" Style="{StaticResource GhostButton}" VerticalAlignment="Top" ToolTip="Hide">
            <TextBlock x:Name="CloseGlyph" Text="&#xE8BB;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="10"/>
          </Button>
        </Grid>
        <TextBlock x:Name="MessageBlock" TextWrapping="Wrap" FontSize="13.5" LineHeight="20" Margin="0,16,0,0"/>
        <Border x:Name="CountdownPanel" CornerRadius="8" Padding="14,12" Margin="0,16,0,0">
          <StackPanel>
            <Grid>
              <TextBlock x:Name="CountdownLabel" FontSize="12.5" VerticalAlignment="Center"/>
              <TextBlock x:Name="CountdownText" FontSize="26" FontWeight="SemiBold" FontFamily="Segoe UI Variable Display, Segoe UI"
                         HorizontalAlignment="Right" VerticalAlignment="Center"/>
            </Grid>
            <Grid Height="6" Margin="0,10,0,0">
              <Border x:Name="ProgressTrack" CornerRadius="3"/>
              <Border x:Name="ProgressFill" CornerRadius="3" HorizontalAlignment="Left" Width="0"/>
            </Grid>
            <TextBlock x:Name="HintBlock" FontSize="12" TextWrapping="Wrap" Margin="0,10,0,0"/>
          </StackPanel>
        </Border>
        <Grid Margin="0,18,0,0">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>
          <Button x:Name="LaterButton" Grid.Column="0" Margin="0,0,6,0" Style="{StaticResource PillButton}"/>
          <Button x:Name="NowButton" Grid.Column="1" Margin="6,0,0,0" Style="{StaticResource PillButton}" Foreground="White"/>
        </Grid>
      </StackPanel>
    </Border>
  </Grid>
</Window>
"@

$Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $Xaml))
$Controls = @{}
foreach ($Name in @("Card", "SlideTransform", "IconCircle", "TitleBlock", "CompanyBlock", "CloseButton", "CloseGlyph", "MessageBlock", "CountdownPanel",
                    "CountdownLabel", "CountdownText", "ProgressTrack", "ProgressFill", "HintBlock", "LaterButton", "NowButton")) {
    $Controls[$Name] = $Window.FindName($Name)
}

function New-Brush {
    param ([string]$Hex)
    $Brush = (New-Object System.Windows.Media.BrushConverter).ConvertFromString($Hex)
    $Brush.Freeze()
    return $Brush
}

# Step 5: Apply theme and texts
$Controls.Card.Background = New-Brush $Palette.Card
$Controls.Card.BorderBrush = New-Brush $Palette.Stroke
$Controls.TitleBlock.Foreground = New-Brush $Palette.Text
$Controls.MessageBlock.Foreground = New-Brush $Palette.Text
$Controls.CountdownText.Foreground = New-Brush $Palette.Text
$Controls.CompanyBlock.Foreground = New-Brush $Palette.Secondary
$Controls.CountdownLabel.Foreground = New-Brush $Palette.Secondary
$Controls.HintBlock.Foreground = New-Brush $Palette.Secondary
$Controls.CloseGlyph.Foreground = New-Brush $Palette.Secondary
$Controls.CountdownPanel.Background = New-Brush $Palette.Panel
$Controls.ProgressTrack.Background = New-Brush $Palette.Track
$Controls.LaterButton.Background = New-Brush $Palette.SecondaryButton
$Controls.LaterButton.Foreground = New-Brush $Palette.Text

function Set-Accent {
    param ([string]$Hex)
    $Brush = New-Brush $Hex
    $Controls.IconCircle.Fill = $Brush
    $Controls.ProgressFill.Background = $Brush
    $Controls.NowButton.Background = $Brush
}
Set-Accent -Hex $Config.AccentColor

$Controls.TitleBlock.Text = $Config.TitleText
$Controls.CompanyBlock.Text = $Config.CompanyName
$Controls.MessageBlock.Text = $Config.MessageText -f $Config.UptimeDays
$Controls.CountdownLabel.Text = $Config.CountdownLabelText
$Controls.HintBlock.Text = $Config.HintText -f $Deadline.ToString("HH:mm")
$Controls.LaterButton.Content = $Config.ButtonLaterText
$Controls.NowButton.Content = $Config.ButtonNowText

# Step 6: Helpers for position, animation and visibility
$script:IsHidden = $false
$script:NextShowTime = $null
$script:FinalPhase = $false
$script:Finished = $false
$script:FinishedAt = $null
$script:AllowClose = $false

function Set-PopupPosition {
    $WorkArea = [System.Windows.SystemParameters]::WorkArea
    $Window.Left = $WorkArea.Right - $Window.ActualWidth
    $Window.Top = $WorkArea.Bottom - $Window.ActualHeight
}

function Start-ShowAnimation {
    $Ease = New-Object System.Windows.Media.Animation.CubicEase
    $Ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
    $Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(380))
    $Fade = New-Object System.Windows.Media.Animation.DoubleAnimation(0, 1, $Duration)
    $Fade.EasingFunction = $Ease
    $Slide = New-Object System.Windows.Media.Animation.DoubleAnimation(24, 0, $Duration)
    $Slide.EasingFunction = $Ease
    $Controls.Card.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $Fade)
    $Controls.SlideTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $Slide)
}

function Show-Popup {
    $script:IsHidden = $false
    $script:NextShowTime = $null
    $Window.Show()
    $Window.UpdateLayout()
    Set-PopupPosition
    Start-ShowAnimation
}

function Hide-Popup {
    $script:IsHidden = $true
    $script:NextShowTime = (Get-Date).AddMinutes([int]$Config.SnoozeMinutes)
    $Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(220))
    $FadeOut = New-Object System.Windows.Media.Animation.DoubleAnimation(1, 0, $Duration)
    $FadeOut.Add_Completed({ if ($script:IsHidden) { $Window.Hide() } })
    $Controls.Card.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $FadeOut)
    Write-PopupLog "Snoozed until $($script:NextShowTime)"
}

function Enter-FinalPhase {
    $script:FinalPhase = $true
    Set-Accent -Hex $Config.FinalAccentColor
    $Controls.LaterButton.Visibility = "Collapsed"
    $Controls.CloseButton.Visibility = "Collapsed"
    [System.Windows.Controls.Grid]::SetColumn($Controls.NowButton, 0)
    [System.Windows.Controls.Grid]::SetColumnSpan($Controls.NowButton, 2)
    $Controls.NowButton.Margin = [System.Windows.Thickness]::new(0)
    if ($script:IsHidden) { Show-Popup }
    Write-PopupLog "Final phase reached"
}

function Update-Countdown {
    $Remaining = $Deadline - (Get-Date)
    if ($Remaining.TotalSeconds -le 0) {
        if (-not $script:Finished) {
            $script:Finished = $true
            $script:FinishedAt = Get-Date
            $Controls.CountdownText.Text = "00:00:00"
            $Controls.ProgressFill.Width = 0
            $Controls.MessageBlock.Text = $Config.RestartingText
            $Controls.NowButton.IsEnabled = $false
            if ($script:IsHidden) { Show-Popup }
            Write-PopupLog "Deadline reached, enforced reboot handled by SYSTEM task"
        }
        elseif (((Get-Date) - $script:FinishedAt).TotalSeconds -ge 120) {
            $script:AllowClose = $true
            $App.Shutdown()
        }
        return
    }
    $Controls.CountdownText.Text = "{0:00}:{1:00}:{2:00}" -f [math]::Floor($Remaining.TotalHours), $Remaining.Minutes, $Remaining.Seconds
    $TrackWidth = $Controls.ProgressTrack.ActualWidth
    if ($TrackWidth -gt 0) {
        $Controls.ProgressFill.Width = [math]::Max(0, $TrackWidth * ($Remaining.TotalSeconds / $TotalSeconds))
    }
    if (-not $script:FinalPhase -and $Remaining.TotalMinutes -le [int]$Config.FinalPhaseMinutes) {
        Enter-FinalPhase
    }
    if ($script:IsHidden -and $script:NextShowTime -and (Get-Date) -ge $script:NextShowTime) {
        Show-Popup
    }
}

# Step 7: Events
$Window.Add_Loaded({ Set-PopupPosition; Start-ShowAnimation; Update-Countdown })
$Window.Add_Closing({ param($SenderObject, $CloseArgs) if (-not $script:AllowClose) { $CloseArgs.Cancel = $true } })
$Controls.LaterButton.Add_Click({ Hide-Popup })
$Controls.CloseButton.Add_Click({ Hide-Popup })
$Controls.NowButton.Add_Click({
    $Controls.NowButton.IsEnabled = $false
    $Controls.LaterButton.IsEnabled = $false
    $Controls.MessageBlock.Text = $Config.RestartingText
    try {
        Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" -ArgumentList "/r /t 10 /d p:0:0 /c `"$($Config.ShutdownComment)`"" -WindowStyle Hidden -ErrorAction Stop
        Write-PopupLog "User $env:USERNAME triggered the reboot"
    }
    catch {
        Write-PopupLog "Reboot by user failed: $($_.Exception.Message)"
        $Controls.NowButton.IsEnabled = $true
    }
})

$Timer = New-Object System.Windows.Threading.DispatcherTimer
$Timer.Interval = [TimeSpan]::FromSeconds(1)
$Timer.Add_Tick({ Update-Countdown })
$Timer.Start()

# Step 8: Run
$App = New-Object System.Windows.Application
$App.ShutdownMode = [System.Windows.ShutdownMode]::OnExplicitShutdown
[void]$App.Run($Window)
'@

# ==========================================================================
# Functions
# ==========================================================================

function Write-Log {
    param ([string]$Message)
    try {
        $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $LogFile -Value "$TimeStamp [Remediate] $Message" -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        # Logging must never break remediation
    }
}

function Set-RegistryValue {
    param ([string]$Name, $Value, [string]$Type = "String")
    New-ItemProperty -Path $RegPath -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

# ==========================================================================
# Logic
# ==========================================================================

try {
    # Step 1: Determine uptime and existing state
    $Now = Get-Date
    $LastBoot = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).LastBootUpTime
    $UptimeDays = [math]::Floor(($Now - $LastBoot).TotalDays)
    if ($null -ne $TestUptimeDays) {
        $UptimeDays = [int]$TestUptimeDays
        Write-Log "Testing value active, uptime overridden to $UptimeDays days"
    }
    Write-Log "Remediation started, uptime $UptimeDays days (limit $MaxUptimeDays)"

    # Step 2: A schedule from this boot session is overdue, the enforced reboot did not happen
    $State = Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue
    if ($State -and $State.ScheduledAtUtcTicks -and $State.DeadlineUtcTicks) {
        $PreviousScheduledAt = ([datetime]::new([int64]$State.ScheduledAtUtcTicks, [DateTimeKind]::Utc)).ToLocalTime()
        $PreviousDeadline = ([datetime]::new([int64]$State.DeadlineUtcTicks, [DateTimeKind]::Utc)).ToLocalTime()
        if ($PreviousScheduledAt -gt $LastBoot -and $Now -gt $PreviousDeadline) {
            Write-Log "Previous deadline $PreviousDeadline is overdue, forcing reboot in $NoUserRebootDelaySeconds seconds"
            & "$env:SystemRoot\System32\shutdown.exe" /r /f /t $NoUserRebootDelaySeconds /d p:0:0 /c "$ShutdownComment"
            Write-Output "Overdue: enforced reboot in $NoUserRebootDelaySeconds seconds"
            exit 0
        }
    }

    # Step 3: Disable Fast Startup (takes effect with the upcoming reboot)
    if ($DisableFastStartup) {
        $PowerKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
        if ((Get-ItemProperty -Path $PowerKey -Name HiberbootEnabled -ErrorAction SilentlyContinue).HiberbootEnabled -ne 0) {
            Set-ItemProperty -Path $PowerKey -Name HiberbootEnabled -Value 0 -Type DWord -Force
            Write-Log "Fast Startup disabled"
        }
    }

    # Step 4: Write schedule and popup configuration to HKLM (readable by users)
    $Deadline = $Now.AddMinutes($CountdownMinutes)
    if (-not (Test-Path -Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
    Set-RegistryValue -Name "ScheduledAtUtcTicks" -Value $Now.ToUniversalTime().Ticks -Type "QWord"
    Set-RegistryValue -Name "DeadlineUtcTicks" -Value $Deadline.ToUniversalTime().Ticks -Type "QWord"
    Set-RegistryValue -Name "UptimeDays" -Value $UptimeDays -Type "DWord"
    Set-RegistryValue -Name "SnoozeMinutes" -Value $SnoozeMinutes -Type "DWord"
    Set-RegistryValue -Name "FinalPhaseMinutes" -Value $FinalPhaseMinutes -Type "DWord"
    Set-RegistryValue -Name "CompanyName" -Value $CompanyName
    Set-RegistryValue -Name "AccentColor" -Value $AccentColor
    Set-RegistryValue -Name "FinalAccentColor" -Value $FinalAccentColor
    Set-RegistryValue -Name "TitleText" -Value $TitleText
    Set-RegistryValue -Name "MessageText" -Value $MessageText
    Set-RegistryValue -Name "CountdownLabelText" -Value $CountdownLabelText
    Set-RegistryValue -Name "HintText" -Value $HintText
    Set-RegistryValue -Name "ButtonNowText" -Value $ButtonNowText
    Set-RegistryValue -Name "ButtonLaterText" -Value $ButtonLaterText
    Set-RegistryValue -Name "RestartingText" -Value $RestartingText
    Set-RegistryValue -Name "ShutdownComment" -Value $ShutdownComment
    Write-Log "Deadline set to $Deadline"

    # Step 5: Deploy popup script with a locked down ACL (users read and execute only)
    if (-not (Test-Path -Path $BasePath)) { New-Item -Path $BasePath -ItemType Directory -Force | Out-Null }
    $Acl = New-Object System.Security.AccessControl.DirectorySecurity
    $Acl.SetAccessRuleProtection($true, $false)
    $Inheritance = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
    $Propagation = [System.Security.AccessControl.PropagationFlags]::None
    foreach ($Entry in @(@("S-1-5-18", "FullControl"), @("S-1-5-32-544", "FullControl"), @("S-1-5-32-545", "ReadAndExecute"))) {
        $Sid = New-Object System.Security.Principal.SecurityIdentifier($Entry[0])
        $Rule = New-Object System.Security.AccessControl.FileSystemAccessRule($Sid, $Entry[1], $Inheritance, $Propagation, "Allow")
        $Acl.AddAccessRule($Rule)
    }
    Set-Acl -Path $BasePath -AclObject $Acl
    $PopupScript | Set-Content -Path $PopupFile -Encoding UTF8 -Force
    Write-Log "Popup script deployed to $PopupFile"

    # Step 6: Register the enforced reboot (SYSTEM, one time, runs as soon as possible if the deadline was missed)
    foreach ($TaskName in @($PopupTaskName, $RebootTaskName)) {
        Unregister-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    }
    # Guard: only reboot if the device has not booted since the schedule was created (e.g. user shut down and powered on after the deadline)
    $ScheduledAtTicks = $Now.ToUniversalTime().Ticks
    $GuardScript = "if ((Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime -lt ([datetime]::new($ScheduledAtTicks, [DateTimeKind]::Utc)).ToLocalTime()) { & `"$env:SystemRoot\System32\shutdown.exe`" /r /f /t 60 /d p:0:0 /c `"$ShutdownComment`" }"
    $EncodedGuard = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($GuardScript))
    $RebootAction = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand $EncodedGuard"
    $RebootTrigger = New-ScheduledTaskTrigger -Once -At $Deadline
    $RebootPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $RebootSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
    Register-ScheduledTask -TaskPath $TaskPath -TaskName $RebootTaskName -Action $RebootAction -Trigger $RebootTrigger -Principal $RebootPrincipal -Settings $RebootSettings -Description "Enforced maintenance reboot (Intune Remediation)" -ErrorAction Stop | Out-Null
    Write-Log "Enforced reboot task registered for $Deadline"

    # Step 7: Nobody signed in, no popup needed
    $InteractiveSessions = @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction SilentlyContinue)
    if ($InteractiveSessions.Count -eq 0 -and $RebootImmediatelyIfNoUser) {
        Write-Log "No interactive session found, rebooting in $NoUserRebootDelaySeconds seconds"
        & "$env:SystemRoot\System32\shutdown.exe" /r /f /t $NoUserRebootDelaySeconds /d p:0:0 /c "$ShutdownComment"
        Write-Output "No user signed in: reboot in $NoUserRebootDelaySeconds seconds (uptime $UptimeDays days)"
        exit 0
    }

    # Step 8: Register and start the popup task for all interactive users (re-launch every 15 minutes and at logon)
    $PowerShellExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $PopupArguments = "--headless `"$PowerShellExe`" -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$PopupFile`" -RegPath `"$RegPath`""
    $PopupAction = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\conhost.exe" -Argument $PopupArguments
    $PopupTriggers = @(
        (New-ScheduledTaskTrigger -AtLogOn),
        (New-ScheduledTaskTrigger -Once -At $Now.AddSeconds(5) -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration (New-TimeSpan -Minutes $CountdownMinutes))
    )
    $PopupPrincipal = New-ScheduledTaskPrincipal -GroupId "S-1-5-32-545" -RunLevel Limited
    $PopupSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances Parallel -ExecutionTimeLimit (New-TimeSpan -Minutes ($CountdownMinutes + 30))
    Register-ScheduledTask -TaskPath $TaskPath -TaskName $PopupTaskName -Action $PopupAction -Trigger $PopupTriggers -Principal $PopupPrincipal -Settings $PopupSettings -Description "Reboot reminder popup (Intune Remediation)" -ErrorAction Stop | Out-Null
    Start-ScheduledTask -TaskPath $TaskPath -TaskName $PopupTaskName -ErrorAction Stop
    Write-Log "Popup task registered and started"

    Write-Output "Popup shown, enforced reboot at $($Deadline.ToString("yyyy-MM-dd HH:mm")) (uptime $UptimeDays days)"
    exit 0
}
catch {
    Write-Log "Remediation failed: $($_.Exception.Message)"
    Write-Error "Remediation failed: $($_.Exception.Message)"
    exit 1
}
