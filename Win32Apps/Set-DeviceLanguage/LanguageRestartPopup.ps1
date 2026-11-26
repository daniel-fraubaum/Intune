<#
    Script:      LanguageRestartPopup.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.0
    Date:        2026-11-24
    Description: WPF restart reminder shown after a display language change by Set-DeviceLanguage.ps1.
                 Copied to Program Files and started in every user session by a scheduled task.
                 Reads all settings from HKLM. Without a deadline it only reminds the user, with a
                 deadline it shows a live countdown (the restart itself is done by a SYSTEM task).
                 Exits without showing anything if the device has restarted since the language
                 change, or if the RebootReminder popup is already running in this session.
#>

# ==========================================================================================
# Parameters
# ==========================================================================================
param (
    # Registry key with schedule, texts and colors (written by Set-DeviceLanguage.ps1)
    [Parameter(Mandatory = $true)]
    [string]$RegPath
)

# Log file in the profile of the signed-in user
$LogFile = "$env:TEMP\LanguageRestartPopup.log"

# Mutex names: this popup and the RebootReminder popup (Remediations/RebootReminder)
$MutexName = "Local\LanguageRestartPopup"
$RebootReminderMutexName = "Local\RebootReminderPopup"

# ==========================================================================================
# Logic
# ==========================================================================================

function Write-PopupLog {
    param ([string]$Message)
    try { Add-Content -Path $LogFile -Value "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") $Message" -Encoding UTF8 } catch { }
}

# Step 1: One instance per session
$Mutex = New-Object System.Threading.Mutex($false, $MutexName)
if (-not $Mutex.WaitOne(0)) { exit 0 }

# Step 2: Stay quiet while the RebootReminder popup is active, one restart covers both
$ExistingMutex = $null
if ([System.Threading.Mutex]::TryOpenExisting($RebootReminderMutexName, [ref]$ExistingMutex)) {
    $ExistingMutex.Dispose()
    Write-PopupLog "RebootReminder popup is active in this session, language popup skipped"
    exit 0
}

# Step 3: Read configuration and check if the restart is still pending
$Config = Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue
if (-not $Config -or -not $Config.ScheduledAtUtcTicks) { exit 0 }
$ScheduledAt = ([datetime]::new([int64]$Config.ScheduledAtUtcTicks, [DateTimeKind]::Utc)).ToLocalTime()
$LastBoot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
if ($LastBoot -gt $ScheduledAt) { exit 0 }

$Enforced = [int64]$Config.DeadlineUtcTicks -gt 0
if ($Enforced) {
    $Deadline = ([datetime]::new([int64]$Config.DeadlineUtcTicks, [DateTimeKind]::Utc)).ToLocalTime()
    if ((Get-Date) -ge $Deadline) { exit 0 }
    $TotalSeconds = [math]::Max(1, ($Deadline - $ScheduledAt).TotalSeconds)
    Write-PopupLog "Popup started for $env:USERNAME, enforced restart at $Deadline"
}
else {
    Write-PopupLog "Popup started for $env:USERNAME, reminder only"
}

# Step 4: Theme (follows the Windows app theme)
$ThemeKey = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -ErrorAction SilentlyContinue
$IsLight = $ThemeKey.AppsUseLightTheme -eq 1
if ($IsLight) {
    $Palette = @{ Card = "#F7FBFBFB"; Stroke = "#1A000000"; Text = "#E6000000"; Secondary = "#99000000"; Panel = "#0A000000"; Track = "#1A000000"; SecondaryButton = "#0F000000" }
}
else {
    $Palette = @{ Card = "#F2202020"; Stroke = "#33FFFFFF"; Text = "#FFFFFFFF"; Secondary = "#B3FFFFFF"; Panel = "#14FFFFFF"; Track = "#26FFFFFF"; SecondaryButton = "#1FFFFFFF" }
}

# Step 5: Build the window
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
            <TextBlock x:Name="IconGlyph" Text="&#xE775;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="18"
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

# Step 6: Apply theme and texts
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
$Controls.MessageBlock.Text = $Config.MessageText -f $Config.LanguageName
$Controls.LaterButton.Content = $Config.ButtonLaterText
$Controls.NowButton.Content = $Config.ButtonNowText

if ($Enforced) {
    $Controls.CountdownLabel.Text = $Config.CountdownLabelText
    $Controls.HintBlock.Text = $Config.HintText -f $Deadline.ToString("HH:mm")
}
else {
    $Controls.CountdownPanel.Visibility = "Collapsed"
}

# Step 7: Helpers for position, animation and visibility
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
    $script:NextShowTime = (Get-Date).AddMinutes([int]$Config.ReminderIntervalMinutes)
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

function Update-Popup {
    # Reminder only: show the popup again after the snooze interval
    if (-not $Enforced) {
        if ($script:IsHidden -and $script:NextShowTime -and (Get-Date) -ge $script:NextShowTime) {
            Show-Popup
        }
        return
    }

    # Enforced: live countdown until the SYSTEM task restarts the device
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
            Write-PopupLog "Deadline reached, enforced restart handled by SYSTEM task"
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

# Step 8: Events
$Window.Add_Loaded({ Set-PopupPosition; Start-ShowAnimation; Update-Popup })
$Window.Add_Closing({ param($SenderObject, $CloseArgs) if (-not $script:AllowClose) { $CloseArgs.Cancel = $true } })
$Controls.LaterButton.Add_Click({ Hide-Popup })
$Controls.CloseButton.Add_Click({ Hide-Popup })
$Controls.NowButton.Add_Click({
    $Controls.NowButton.IsEnabled = $false
    $Controls.LaterButton.IsEnabled = $false
    $Controls.MessageBlock.Text = $Config.RestartingText
    try {
        Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" -ArgumentList "/r /t 10 /d p:0:0 /c `"$($Config.ShutdownComment)`"" -WindowStyle Hidden -ErrorAction Stop
        Write-PopupLog "User $env:USERNAME triggered the restart"
    }
    catch {
        Write-PopupLog "Restart by user failed: $($_.Exception.Message)"
        $Controls.NowButton.IsEnabled = $true
        $Controls.LaterButton.IsEnabled = $true
    }
})

$Timer = New-Object System.Windows.Threading.DispatcherTimer
$Timer.Interval = [TimeSpan]::FromSeconds(1)
$Timer.Add_Tick({ Update-Popup })
$Timer.Start()

# Step 9: Run
$App = New-Object System.Windows.Application
$App.ShutdownMode = [System.Windows.ShutdownMode]::OnExplicitShutdown
[void]$App.Run($Window)
