param([string]$Snapshot)
# Gadżet na pulpit: animowany GIF Jana Pawła II + dymek z jego cytatami.
# Klik lewym = następny cytat, prawy = menu (przeczytaj / następny / zamknij).
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing, System.Runtime.WindowsRuntime

$Dir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$Gif  = Join-Path $Dir 'papaj.gif'
$File = Join-Path $Dir 'papaj_cytaty.txt'
$Co   = 45      # co ile sekund zmiana cytatu
$PopeW = 240    # szerokość obrazka

$mtxName = if ($Snapshot) { 'PapajGadgetSnap' } else { 'PapajGadget' }
$created = $false
$mtx = New-Object Threading.Mutex($true, $mtxName, [ref]$created)
if (-not $created) { return }

Add-Type @"
using System; using System.Runtime.InteropServices;
public static class PPJ {
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
    [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
    [DllImport("kernel32.dll")] static extern bool GetSystemTimes(out long idle, out long kernel, out long user);
    [StructLayout(LayoutKind.Sequential)]
    public class MEMSTAT { public uint len = 64; public uint load; public ulong totPhys, availPhys, totPage, availPage, totVirt, availVirt, availExt; }
    [DllImport("kernel32.dll")] static extern bool GlobalMemoryStatusEx([In, Out] MEMSTAT m);
    public static uint MemLoad() { var m = new MEMSTAT(); GlobalMemoryStatusEx(m); return m.load; }
    static long pi, pk, pu;
    public static double Cpu() {
        long i, k, u; GetSystemTimes(out i, out k, out u);
        long di = i - pi, dt = (k - pk) + (u - pu); pi = i; pk = k; pu = u;
        return dt > 0 ? Math.Max(0, Math.Min(100, (dt - di) * 100.0 / dt)) : 0;
    }
}
"@

# --- organy: generowany raz do organy.wav (kadencja "Amen" C-F-C, rejestry + pogłos kościelny) ---
$OrganWav = Join-Path $Dir 'organy.wav'
if (-not (Test-Path $OrganWav)) {
    Add-Type @"
using System; using System.IO;
public static class OrganGen {
    static double F(int m) { return 440.0 * Math.Pow(2, (m - 69) / 12.0); }
    public static void Write(string path) {
        int sr = 44100; double total = 6.5; int N = (int)(sr * total);
        double[] buf = new double[N];
        int[][] chords = { new[]{36,48,52,55,60,64,67}, new[]{41,53,57,60,65,69,72}, new[]{36,48,52,55,60,64,67,72} };
        double[] st = { 0.0, 1.3, 2.6 }, en = { 1.4, 2.7, 4.6 };
        double[] hm = { 1, 2, 3, 4, 6, 8 }, ha = { 1.0, 0.55, 0.22, 0.28, 0.10, 0.08 };
        for (int c = 0; c < chords.Length; c++) {
            double rel = (c == chords.Length - 1) ? 1.6 : 0.12;
            int s0 = (int)(st[c] * sr), s1 = Math.Min(N, (int)((en[c] + rel) * sr));
            foreach (int m in chords[c]) {
                double f = F(m), amp = (m < 45) ? 0.9 : 0.5;
                for (int i = s0; i < s1; i++) {
                    double t = (i - s0) / (double)sr, tt = i / (double)sr;
                    double env = Math.Min(1, t / 0.07);
                    double tEnd = tt - en[c]; if (tEnd > 0) env *= Math.Exp(-tEnd * 4.0 / rel);
                    double v = 0;
                    for (int h = 0; h < hm.Length; h++) {
                        double fh = f * hm[h]; if (fh > 9000) break;
                        v += ha[h] * (Math.Sin(2 * Math.PI * fh * tt) + 0.5 * Math.Sin(2 * Math.PI * fh * 1.0025 * tt));
                    }
                    v *= 1 + 0.05 * Math.Sin(2 * Math.PI * 5.3 * tt);   // tremolo
                    buf[i] += v * env * amp;
                }
            }
        }
        // pogłos Schroedera
        int[] cd = { 1557, 1617, 1491, 1422 }; double[] out1 = new double[N];
        foreach (int d in cd) { double[] cb = new double[d]; int p = 0;
            for (int i = 0; i < N; i++) { double y = cb[p]; cb[p] = buf[i] + y * 0.84; p = (p + 1) % d; out1[i] += y * 0.25; } }
        foreach (int d in new[]{ 225, 556 }) { double[] ab = new double[d]; int p = 0;
            for (int i = 0; i < N; i++) { double b = ab[p]; double y = -out1[i] + b; ab[p] = out1[i] + b * 0.5; p = (p + 1) % d; out1[i] = y; } }
        double peak = 1e-9; for (int i = 0; i < N; i++) { buf[i] = buf[i] * 0.7 + out1[i] * 0.45; peak = Math.Max(peak, Math.Abs(buf[i])); }
        int fade = sr / 2;
        using (var w = new BinaryWriter(File.Create(path))) {
            w.Write(new[]{'R','I','F','F'}); w.Write(36 + N * 2); w.Write(new[]{'W','A','V','E','f','m','t',' '});
            w.Write(16); w.Write((short)1); w.Write((short)1); w.Write(sr); w.Write(sr * 2); w.Write((short)2); w.Write((short)16);
            w.Write(new[]{'d','a','t','a'}); w.Write(N * 2);
            for (int i = 0; i < N; i++) { double g = (i > N - fade) ? (N - i) / (double)fade : 1;
                w.Write((short)(buf[i] / peak * 0.55 * g * 32767)); }
        }
    }
}
"@
    [OrganGen]::Write($OrganWav)
}
$script:organ = New-Object System.Media.SoundPlayer $OrganWav
try { $script:organ.Load() } catch { }

# --- klatki GIF-a (GDI+ zwraca klatki już złożone) ---
$frames = New-Object System.Collections.Generic.List[object]
$delays = New-Object System.Collections.Generic.List[int]
$img = [System.Drawing.Image]::FromFile($Gif)
$fd  = New-Object System.Drawing.Imaging.FrameDimension($img.FrameDimensionsList[0])
$n   = $img.GetFrameCount($fd)
$dl  = $null
try { $dl = $img.GetPropertyItem(0x5100).Value } catch { }
for ($i = 0; $i -lt $n; $i++) {
    [void]$img.SelectActiveFrame($fd, $i)
    $bmp = New-Object System.Drawing.Bitmap($img.Width, $img.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.DrawImage($img, 0, 0, $img.Width, $img.Height); $g.Dispose()
    $ms = New-Object IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    $ms.Position = 0
    $bi = New-Object Windows.Media.Imaging.BitmapImage
    $bi.BeginInit(); $bi.CacheOption = 'OnLoad'; $bi.StreamSource = $ms; $bi.EndInit(); $bi.Freeze()
    $frames.Add($bi)
    $d = 10
    if ($dl -and $dl.Length -ge ($i * 4 + 4)) { $d = [BitConverter]::ToInt32($dl, $i * 4) }
    if ($d -lt 2) { $d = 10 }
    $delays.Add($d * 10)
}
$ratio = $img.Height / $img.Width
$img.Dispose()

# --- cytaty ---
$quotes = @(Get-Content $File -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object {
    $p = $_.Split('|'); [pscustomobject]@{ T = $p[0].Trim(); S = $(if ($p.Count -gt 1) { $p[1].Trim() } else { '' }) }
})
$rnd = New-Object Random
$script:qi = $rnd.Next($quotes.Count)

$oq = [string][char]0x201E; $cq = [string][char]0x201D
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ShowInTaskbar="False" ResizeMode="NoResize" SizeToContent="Height" Width="330"
        Title="Papaj" FontFamily="Segoe UI Variable Text, Segoe UI">
  <StackPanel x:Name="Root">
    <Grid x:Name="Bubble" Margin="6,0,6,0">
      <Border CornerRadius="22" Margin="0,2,0,0" Background="#40000000">
        <Border.Effect><BlurEffect Radius="14"/></Border.Effect>
      </Border>
      <Border CornerRadius="22" Background="#B81C1C24" BorderBrush="#70FFFFFF" BorderThickness="1" Padding="18,14,18,14">
        <StackPanel>
          <TextBlock Text="JAN PAWEŁ II" FontSize="11" FontWeight="SemiBold" Foreground="#FFD60A" Margin="0,0,0,6"/>
          <TextBlock x:Name="QText" TextWrapping="Wrap" FontSize="16" Foreground="White" LineHeight="22"/>
          <TextBlock x:Name="QSrc" TextWrapping="Wrap" FontSize="11.5" Foreground="#B0FFFFFF" Margin="0,8,0,0" FontStyle="Italic"/>
        </StackPanel>
      </Border>
    </Grid>
    <Path Data="M0,0 L22,0 L6,18 Z" Fill="#B81C1C24" Margin="150,-1,0,0" HorizontalAlignment="Left"/>
    <Image x:Name="Pope" Width="$PopeW" Height="$([int]($PopeW * $ratio))" Margin="0,2,0,0" HorizontalAlignment="Center"
           RenderOptions.BitmapScalingMode="HighQuality">
      <Image.Effect><DropShadowEffect BlurRadius="18" ShadowDepth="3" Opacity="0.45"/></Image.Effect>
    </Image>
  </StackPanel>
</Window>
"@
$win    = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $xaml))
$Pope   = $win.FindName('Pope')
$QText  = $win.FindName('QText')
$QSrc   = $win.FindName('QSrc')
$Bubble = $win.FindName('Bubble')
$Root   = $win.FindName('Root')

function Show-Quote([int]$idx) {
    $q = $quotes[$idx]
    $QText.Text = $oq + $q.T + $cq
    $QSrc.Text  = if ($q.S -and $q.S -ne 'Jan Paweł II') { '— ' + $q.S } else { '' }
    $QSrc.Visibility = if ($QSrc.Text) { 'Visible' } else { 'Collapsed' }
    $a = New-Object Windows.Media.Animation.DoubleAnimation(0, 1, [TimeSpan]::FromMilliseconds(600))
    $Bubble.BeginAnimation([Windows.UIElement]::OpacityProperty, $a)
}
function Next-Quote {
    $j = $script:qi
    if ($quotes.Count -gt 1) { while ($j -eq $script:qi) { $j = $rnd.Next($quotes.Count) } }
    $script:qi = $j; $script:since = 0; Show-Quote $j
}

# --- mowa: OneCore TTS (widzi nowoczesne głosy, w tym polskie), odtwarzanie przez MediaPlayer ---
# papież rusza się TYLKO gdy mówi: MediaOpened -> animacja, MediaEnded -> bezruch + ewentualne schowanie
$null = [Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media, ContentType = WindowsRuntime]
$null = [Windows.Media.SpeechSynthesis.SpeechSynthesisStream, Windows.Media, ContentType = WindowsRuntime]
$script:asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    })[0]
function Await-WinRT($op, $t) { $task = $script:asTask.MakeGenericMethod($t).Invoke($null, @($op)); [void]$task.Wait(-1); $task.Result }

$script:ttsSynth = $null
$script:ttsWav = Join-Path $env:TEMP 'papaj_tts.wav'
function Init-Tts {
    if ($script:ttsSynth) { return }
    try {
        $script:ttsSynth = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::new()
        # polski głos, gdy jest (Paulina/Adam); inaczej głos domyślny systemu (fallback)
        $pl = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices | Where-Object { $_.Language -like 'pl*' } | Select-Object -First 1
        if ($pl) { $script:ttsSynth.Voice = $pl }
    } catch { $script:ttsSynth = $null }
}
$script:ttsPlayer = New-Object Windows.Media.MediaPlayer
$script:ttsPlayer.add_MediaOpened({ $anim.Start(); $script:ttsPlayer.Play() })
$script:ttsPlayer.add_MediaEnded({
    $anim.Stop(); $script:fi = 0; $Pope.Source = $frames[0]
    try { $script:ttsPlayer.Close() } catch { }
    if ($script:awaitingHide) { $script:awaitingHide = $false; Hold 900 { Finish-Show } }
})
$script:ttsPlayer.add_MediaFailed({
    $anim.Stop(); $script:fi = 0; $Pope.Source = $frames[0]
    if ($script:awaitingHide) { $script:awaitingHide = $false; Hold 300 { Finish-Show } }
})
function Speak-Text([string]$text) {
    Init-Tts
    if (-not $script:ttsSynth) { return $false }
    try {
        try { $script:ttsPlayer.Stop(); $script:ttsPlayer.Close() } catch { }
        $stream = Await-WinRT ($script:ttsSynth.SynthesizeTextToStreamAsync($text)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
        $net = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($stream)
        $fs = [IO.File]::Create($script:ttsWav)
        $net.CopyTo($fs); $fs.Close(); $net.Dispose()
        $script:ttsPlayer.Open([Uri]$script:ttsWav)   # MediaOpened -> animacja + Play
        return $true
    } catch { return $false }
}
function Speak-Quote {
    if (-not (Speak-Text $quotes[$script:qi].T)) {
        if ($script:awaitingHide) { $script:awaitingHide = $false; Hold 300 { Finish-Show } }
    }
}
# organy, a po ~2,7 s (na ostatnim akordzie) lektor czyta cytat
$script:speakDelay = New-Object Windows.Threading.DispatcherTimer
$script:speakDelay.Interval = [TimeSpan]::FromMilliseconds(2700)
$script:speakDelay.Add_Tick({ $script:speakDelay.Stop(); Speak-Quote })
function Organ-AndSpeak {
    $script:speakDelay.Stop()
    try { $script:ttsPlayer.Stop(); $script:ttsPlayer.Close() } catch { }
    try { $script:organ.Stop(); $script:organ.Play() } catch { }
    $script:speakDelay.Start()
}
function Stop-All {
    $script:speakDelay.Stop()
    try { $script:organ.Stop() } catch { }
    try { $script:ttsPlayer.Stop(); $script:ttsPlayer.Close() } catch { }
}

# --- co 30 min: humorystyczny raport o zużyciu RAM i CPU ---
$script:cpuNow = 0
[void][PPJ]::Cpu()   # zasiej pomiar
function Get-SysJoke([int]$cpu, [int]$ram) {
    $rnd2 = $script:rnd
    $cpuLine =
        if ($cpu -ge 85) { @(
            "Procesor haruje w $cpu procentach, poci się biedak jak pielgrzym w samo południe.",
            "Procesor na $cpu procent — pali się niczym znicz na Wszystkich Świętych.",
            "Procesor w $cpu procentach, dzieci moje; ten komputer odprawia prawdziwą drogę krzyżową."
        ) } elseif ($cpu -ge 40) { @(
            "Procesor pracuje na $cpu procent, spokojnie niczym w niedzielne popołudnie.",
            "Procesor zajęty w $cpu procentach — ani za leniwy, ani za gorliwy.",
            "Na procesorze $cpu procent; krząta się jak ministrant przed sumą."
        ) } else { @(
            "Procesor ledwie $cpu procent — odpoczywa, błogosławiony leń.",
            "Procesor na $cpu procent, drzemie jak kościelny po żniwach.",
            "Procesor zaledwie $cpu procent; cisza jak w pustej kaplicy."
        ) }
    $ramLine =
        if ($ram -ge 85) { @(
            "Pamięć RAM w $ram procentach — tłok większy niż na Jasnej Górze w sierpniu. Zamknij parę kart, zanim nastąpi cud.",
            "Pamięci zajęte w $ram procentach, dziatki; ten komputer dźwiga brzemię ponad siły.",
            "RAM w $ram procentach — pęka w szwach niczym konfesjonał przed świętami."
        ) } elseif ($ram -ge 50) { @(
            "Pamięci RAM zajętej $ram procent — w sam raz, ni mało, ni wiele.",
            "RAM na $ram procent; umiarkowanie, cnota to chwalebna.",
            "Pamięć w $ram procentach — jest jeszcze miejsce w tej gospodzie."
        ) } else { @(
            "Pamięć RAM ledwie $ram procent — pustki jak w konfesjonale w sobotni poranek.",
            "RAM zaledwie $ram procent; przestronnie niczym w kościele w poniedziałek.",
            "Pamięci wolnej aż nadto — $ram procent zajęte, reszta czeka na pielgrzymów."
        ) }
    $end = @('Amen.', 'Szczęść Boże.', 'Nie lękajcie się.', 'Czuwajcie.', 'Bóg zapłać za cierpliwość.')
    '{0} {1} {2}' -f $cpuLine[$rnd2.Next($cpuLine.Count)], $ramLine[$rnd2.Next($ramLine.Count)], $end[$rnd2.Next($end.Count)]
}
function Speak-SysStatus {
    $cpu = [int][math]::Round($script:cpuNow)
    $ram = [int][PPJ]::MemLoad()
    if (-not (Speak-Text (Get-SysJoke $cpu $ram))) {
        if ($script:awaitingHide) { $script:awaitingHide = $false; Hold 300 { Finish-Show } }
    }
}
# (harmonogram pokazów zdefiniowany po bloku animacji)

# --- animacja ---
$script:fi = 0
$Pope.Source = $frames[0]
$anim = New-Object Windows.Threading.DispatcherTimer
$anim.Interval = [TimeSpan]::FromMilliseconds($delays[0])
$anim.Add_Tick({
    $script:fi = ($script:fi + 1) % $frames.Count
    $Pope.Source = $frames[$script:fi]
    $anim.Interval = [TimeSpan]::FromMilliseconds($delays[$script:fi])
})

# ================= TŁO: wysuwanie/chowanie + harmonogram =================
# Domyślnie ukryty. Peek co 10 min (bez dźwięku). Co 30 min na zmianę: cytat <-> raport.
$script:busy = $false          # trwa pokaz/peek
$script:sliding = $false       # trwa animacja chowania
$script:awaitingHide = $false  # czekamy na koniec mowy, by schować
$script:cycle = 0              # parzysty -> cytat, nieparzysty -> raport
$script:tt = New-Object Windows.Media.TranslateTransform
$Root.RenderTransform = $script:tt

function Place-Window {
    $wa = [Windows.SystemParameters]::WorkArea
    $win.UpdateLayout()
    $win.Left = $wa.Right - $win.ActualWidth
    $win.Top  = $wa.Bottom - $win.ActualHeight
    $h = (New-Object Windows.Interop.WindowInteropHelper $win).Handle
    if ($h -ne [IntPtr]::Zero) { [void][PPJ]::SetWindowPos($h, [IntPtr](-1), 0, 0, 0, 0, 0x0013) }  # HWND_TOPMOST
}
function Hold([int]$ms, [scriptblock]$cb) {
    $t = New-Object Windows.Threading.DispatcherTimer
    $t.Interval = [TimeSpan]::FromMilliseconds($ms)
    $t.Tag = $cb
    $t.Add_Tick({ $args[0].Stop(); & $args[0].Tag })
    $t.Start()
}
function Animate-Y([double]$to, [int]$ms, [scriptblock]$done) {
    $a = New-Object Windows.Media.Animation.DoubleAnimation($to, [TimeSpan]::FromMilliseconds($ms))
    $a.AccelerationRatio = 0.4; $a.DecelerationRatio = 0.4
    if ($done) { $a.Add_Completed($done) }
    $script:tt.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $a)
}
function Set-ClickThrough([bool]$on) {
    $h = (New-Object Windows.Interop.WindowInteropHelper $win).Handle
    if ($h -eq [IntPtr]::Zero) { return }
    $GWL = -20; $TRANSP = 0x20
    $ex = [PPJ]::GetWindowLong($h, $GWL)
    if ($on) { $ex = $ex -bor $TRANSP } else { $ex = $ex -band (-bnot $TRANSP) }
    [void][PPJ]::SetWindowLong($h, $GWL, $ex)
}
function Hide-Now {
    $script:tt.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $null)
    $script:tt.Y = [math]::Max(1, $win.ActualHeight)
    Set-ClickThrough $true
}
function Finish-Show {
    if (-not $script:busy -or $script:sliding) { return }
    $script:sliding = $true
    $script:awaitingHide = $false
    try { $script:organ.Stop() } catch { }
    Animate-Y ([math]::Max(1, $win.ActualHeight)) 420 { Hide-Now; $script:busy = $false; $script:sliding = $false }
}
function Slide-In([scriptblock]$done) {
    Place-Window
    $script:tt.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $null)
    $script:tt.Y = $win.ActualHeight
    Set-ClickThrough $false
    Place-Window
    Animate-Y 0 420 $done
}
function Run-Show([string]$kind) {
    if ($script:busy) { return }
    $script:busy = $true; $script:sliding = $false; $script:pendingKind = $kind
    if ($kind -eq 'quote') { $Bubble.Visibility = 'Visible'; Next-Quote } else { $Bubble.Visibility = 'Collapsed' }
    Slide-In {
        switch ($script:pendingKind) {
            'peek'   { Hold 2500 { Finish-Show } }   # bez animacji: wyjedź, poczekaj, zjedź
            'quote'  { $script:awaitingHide = $true; Organ-AndSpeak;  Hold 60000 { Finish-Show } }
            'report' { $script:awaitingHide = $true; Speak-SysStatus; Hold 60000 { Finish-Show } }
        }
    }
}

$script:sysTimer = New-Object Windows.Threading.DispatcherTimer
$script:sysTimer.Interval = [TimeSpan]::FromMinutes(30)
$script:sysTimer.Add_Tick({
    if ($script:cycle % 2 -eq 0) { Run-Show 'quote' } else { Run-Show 'report' }
    $script:cycle++
})
$script:peekTimer = New-Object Windows.Threading.DispatcherTimer
$script:peekTimer.Interval = [TimeSpan]::FromMinutes(10)
$script:peekTimer.Add_Tick({ Run-Show 'peek' })

$script:tick = 0
$clock = New-Object Windows.Threading.DispatcherTimer
$clock.Interval = [TimeSpan]::FromSeconds(1)
$clock.Add_Tick({
    $script:tick++
    $script:cpuNow = [PPJ]::Cpu()   # próbkowanie CPU do raportu
    if ($Snapshot -and $script:tick -eq 3) {
        $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap([int]$win.ActualWidth, [int]$win.ActualHeight, 96, 96, 'Pbgra32')
        $rtb.Render($win.Content)
        $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder
        $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($rtb))
        $fs = [IO.File]::Create($Snapshot); $enc.Save($fs); $fs.Close()
        $win.Close()
    }
})

# --- menu (dostępne, gdy papież jest widoczny: podczas peeku/pokazu) ---
$menu = New-Object Windows.Controls.ContextMenu
function Add-Item($txt, $sb) { $mi = New-Object Windows.Controls.MenuItem; $mi.Header = $txt; $mi.Add_Click($sb); [void]$menu.Items.Add($mi) }
Add-Item 'Pokaż cytat teraz'          { Run-Show 'quote' }
Add-Item 'Raport RAM i CPU (na głos)' { Run-Show 'report' }
Add-Item 'Schowaj'                    { Stop-All; Finish-Show }
[void]$menu.Items.Add((New-Object Windows.Controls.Separator))
Add-Item 'Zamknij'                    { $win.Close() }
$win.ContextMenu = $menu
# klik na widocznego papieża = schowaj (i zatrzymaj mowę)
$win.Add_MouseLeftButtonUp({ Stop-All; Finish-Show })

# start UKRYTY (w tle); pokazy sterują timery
$win.Topmost = $true
$win.Add_Activated({ if (-not $script:busy) { Place-Window } })
$win.Add_SizeChanged({ if (-not $script:busy) { Place-Window } })
$win.Add_Loaded({
    $Bubble.Visibility = 'Collapsed'
    Place-Window
    Hide-Now
})

$clock.Start(); $script:sysTimer.Start(); $script:peekTimer.Start()
[void]$win.ShowDialog()
try { $script:ttsPlayer.Close() } catch { }
$mtx.ReleaseMutex()
