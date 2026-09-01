Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName Microsoft.VisualBasic

function Stop-WithMessage([string]$message) {
    [System.Windows.MessageBox]::Show($message, 'Photo Sorter') | Out-Null
    exit
}

function Resolve-ConfiguredPath([string]$path) {
    $expanded = [Environment]::ExpandEnvironmentVariables($path)
    if ([IO.Path]::IsPathRooted($expanded)) { return [IO.Path]::GetFullPath($expanded) }
    return [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $expanded))
}

$configPath = Join-Path $PSScriptRoot 'config.json'
if (-not (Test-Path -LiteralPath $configPath)) {
    Stop-WithMessage "Config file not found:`n$configPath"
}

try {
    $config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
    if (-not $config.sourceFolder -or -not $config.memoriesFolder) { throw 'Missing folder setting' }
    $source = Resolve-ConfiguredPath $config.sourceFolder
    $memories = Resolve-ConfiguredPath $config.memoriesFolder
} catch {
    Stop-WithMessage "Could not read config.json. Check the folder paths and JSON formatting.`n`n$($_.Exception.Message)"
}

$extensions = @('.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tif', '.tiff', '.webp')
$script:photos = @()
$script:index = 0

function Get-Photos {
    $script:photos = @(Get-ChildItem -LiteralPath $source -File | Where-Object {
        $extensions -contains $_.Extension.ToLowerInvariant()
    } | Sort-Object Name)
    if ($script:index -ge $script:photos.Count) { $script:index = [Math]::Max(0, $script:photos.Count - 1) }
}

function Get-FreePath([string]$folder, [string]$name) {
    $candidate = Join-Path $folder $name
    if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
    $stem = [IO.Path]::GetFileNameWithoutExtension($name)
    $ext = [IO.Path]::GetExtension($name)
    $number = 2
    do {
        $candidate = Join-Path $folder "$stem ($number)$ext"
        $number++
    } while (Test-Path -LiteralPath $candidate)
    return $candidate
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Photo Sorter" Width="1100" Height="800" MinWidth="600" MinHeight="450"
        WindowStartupLocation="CenterScreen" Background="#161616">
  <Grid Margin="18">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <Button Name="Keep" Grid.Row="0" Content="&#x2191;  Keep in Memories" Height="52" Margin="140,0,140,14"
            FontSize="18" FontWeight="SemiBold" Background="#2E7D5B" Foreground="White" BorderThickness="0"/>
    <Grid Grid.Row="1">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="82"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="82"/>
      </Grid.ColumnDefinitions>
      <Button Name="Previous" Grid.Column="0" Content="&#x2190;" FontSize="35" Margin="0,0,14,0"
              Background="#292929" Foreground="White" BorderThickness="0"/>
      <Border Grid.Column="1" Background="#050505" CornerRadius="4">
        <Grid>
          <Image Name="Photo" Stretch="Uniform" Margin="8"/>
          <TextBlock Name="Empty" Text="No photos left" Foreground="#BBBBBB" FontSize="28"
                     HorizontalAlignment="Center" VerticalAlignment="Center" Visibility="Collapsed"/>
        </Grid>
      </Border>
      <Button Name="Next" Grid.Column="2" Content="&#x2192;" FontSize="35" Margin="14,0,0,0"
              Background="#292929" Foreground="White" BorderThickness="0"/>
    </Grid>
    <Grid Grid.Row="2" Margin="0,14,0,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <TextBlock Name="Status" Grid.Column="0" Foreground="#AAAAAA" FontSize="14" VerticalAlignment="Center"/>
      <Button Name="Trash" Grid.Column="1" Content="&#x2193;  Move to Recycle Bin" Width="250" Height="52"
              FontSize="18" FontWeight="SemiBold" Background="#9C3F48" Foreground="White" BorderThickness="0"/>
      <TextBlock Grid.Column="2" Text="&#x2190; &#x2192; browse   &#x2191; keep   &#x2193; trash" Foreground="#777777" FontSize="13"
                 HorizontalAlignment="Right" VerticalAlignment="Center"/>
    </Grid>
  </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$photo = $window.FindName('Photo')
$empty = $window.FindName('Empty')
$status = $window.FindName('Status')
$previous = $window.FindName('Previous')
$next = $window.FindName('Next')
$keep = $window.FindName('Keep')
$trash = $window.FindName('Trash')

function Show-Photo {
    if ($script:photos.Count -eq 0) {
        $photo.Source = $null
        $empty.Visibility = 'Visible'
        $status.Text = '0 photos'
        $previous.IsEnabled = $false
        $next.IsEnabled = $false
        $keep.IsEnabled = $false
        $trash.IsEnabled = $false
        return
    }

    $empty.Visibility = 'Collapsed'
    $previous.IsEnabled = $true
    $next.IsEnabled = $true
    $keep.IsEnabled = $true
    $trash.IsEnabled = $true
    $file = $script:photos[$script:index]
    try {
        $bytes = [IO.File]::ReadAllBytes($file.FullName)
        $stream = New-Object IO.MemoryStream(,$bytes)
        $bitmap = New-Object Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = 'OnLoad'
        $bitmap.StreamSource = $stream
        $bitmap.EndInit()
        $bitmap.Freeze()
        $stream.Dispose()
        $photo.Source = $bitmap
        $status.Text = "{0} of {1}  -  {2}" -f ($script:index + 1), $script:photos.Count, $file.Name
    } catch {
        $photo.Source = $null
        $empty.Text = "Cannot display $($file.Name)"
        $empty.Visibility = 'Visible'
        $status.Text = "{0} of {1}" -f ($script:index + 1), $script:photos.Count
    }
}

function Go-Previous {
    if ($script:photos.Count -eq 0) { return }
    $script:index = ($script:index - 1 + $script:photos.Count) % $script:photos.Count
    Show-Photo
}

function Go-Next {
    if ($script:photos.Count -eq 0) { return }
    $script:index = ($script:index + 1) % $script:photos.Count
    Show-Photo
}

function Keep-Photo {
    if ($script:photos.Count -eq 0) { return }
    New-Item -ItemType Directory -Path $memories -Force | Out-Null
    $file = $script:photos[$script:index]
    Move-Item -LiteralPath $file.FullName -Destination (Get-FreePath $memories $file.Name)
    Get-Photos
    Show-Photo
}

function Trash-Photo {
    if ($script:photos.Count -eq 0) { return }
    $file = $script:photos[$script:index]
    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
        $file.FullName,
        [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
        [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
    )
    Get-Photos
    Show-Photo
}

$previous.Add_Click({ Go-Previous })
$next.Add_Click({ Go-Next })
$keep.Add_Click({ Keep-Photo })
$trash.Add_Click({ Trash-Photo })
$window.Add_KeyDown({
    switch ($_.Key) {
        'Left'  { Go-Previous; $_.Handled = $true }
        'Right' { Go-Next; $_.Handled = $true }
        'Up'    { Keep-Photo; $_.Handled = $true }
        'Down'  { Trash-Photo; $_.Handled = $true }
    }
})

if (-not (Test-Path -LiteralPath $source)) {
    Stop-WithMessage "Source folder not found:`n$source`n`nEdit config.json to choose an existing folder."
}

Get-Photos
Show-Photo
$window.Focus() | Out-Null
$window.ShowDialog() | Out-Null
