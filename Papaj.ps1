param([string]$Snapshot)
# Gadżet na pulpit: animowany GIF Jana Pawła II + dymek z jego cytatami.
# Klik lewym = następny cytat, prawy = menu (przeczytaj / następny / zamknij).
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing, System.Speech

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
  <StackPanel>
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

# --- mowa (ten sam głos co w gadżecie Tychy) ---
# papież rusza się TYLKO gdy mówi: start mowy -> animacja, koniec -> bezruch (klatka 0)
$script:syn = $null
function Init-Syn {
    if ($script:syn) { return }
    $script:syn = New-Object System.Speech.Synthesis.SpeechSynthesizer
    try { $script:syn.SelectVoice('Microsoft Paulina Desktop') } catch { }
    $script:syn.Rate = -1
    $script:syn.add_SpeakStarted({ $win.Dispatcher.Invoke([action] { $anim.Start() }) })
    $script:syn.add_SpeakCompleted({ $win.Dispatcher.Invoke([action] { $anim.Stop(); $script:fi = 0; $Pope.Source = $frames[0] }) })
}
function Speak-Quote {
    Init-Syn
    $script:syn.SpeakAsyncCancelAll()
    [void]$script:syn.SpeakAsync($quotes[$script:qi].T)
}
# organy, a po ~2,7 s (na ostatnim akordzie) lektor czyta cytat
$script:speakDelay = New-Object Windows.Threading.DispatcherTimer
$script:speakDelay.Interval = [TimeSpan]::FromMilliseconds(2700)
$script:speakDelay.Add_Tick({ $script:speakDelay.Stop(); Speak-Quote })
function Organ-AndSpeak {
    $script:speakDelay.Stop()
    if ($script:syn) { $script:syn.SpeakAsyncCancelAll() }
    try { $script:organ.Stop(); $script:organ.Play() } catch { }
    $script:speakDelay.Start()
}
function Stop-All {
    $script:speakDelay.Stop()
    try { $script:organ.Stop() } catch { }
    if ($script:syn) { $script:syn.SpeakAsyncCancelAll() }
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
    Init-Syn
    $cpu = [int][math]::Round($script:cpuNow)
    $ram = [int][PPJ]::MemLoad()
    $script:syn.SpeakAsyncCancelAll()
    [void]$script:syn.SpeakAsync((Get-SysJoke $cpu $ram))
}
$script:sysTimer = New-Object Windows.Threading.DispatcherTimer
$script:sysTimer.Interval = [TimeSpan]::FromMinutes(30)
$script:sysTimer.Add_Tick({ Speak-SysStatus })

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

$script:since = 0; $script:tick = 0
$clock = New-Object Windows.Threading.DispatcherTimer
$clock.Interval = [TimeSpan]::FromSeconds(1)
$clock.Add_Tick({
    $script:since++; $script:tick++
    $script:cpuNow = [PPJ]::Cpu()
    if ($script:tick % 5 -eq 0) { Pin-Window }   # utrzymaj w rogu i na wierzchu
    if ($script:since -ge $Co) { Next-Quote }
    if ($Snapshot -and $script:tick -eq 3) {
        $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap([int]$win.ActualWidth, [int]$win.ActualHeight, 96, 96, 'Pbgra32')
        $rtb.Render($win.Content)
        $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder
        $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($rtb))
        $fs = [IO.File]::Create($Snapshot); $enc.Save($fs); $fs.Close()
        $win.Close()
    }
})

# --- menu ---
$menu = New-Object Windows.Controls.ContextMenu
function Add-Item($txt, $sb) { $mi = New-Object Windows.Controls.MenuItem; $mi.Header = $txt; $mi.Add_Click($sb); [void]$menu.Items.Add($mi) }
Add-Item 'Przeczytaj cytat'  { Organ-AndSpeak }
Add-Item 'Następny cytat (bez dźwięku)' { Stop-All; Next-Quote }
Add-Item 'Zatrzymaj czytanie' { Stop-All }
Add-Item 'Raport RAM i CPU (na głos)' { Speak-SysStatus }
[void]$menu.Items.Add((New-Object Windows.Controls.Separator))
Add-Item 'Zamknij'           { $win.Close() }
$win.ContextMenu = $menu
$win.Add_MouseLeftButtonUp({ Next-Quote; Organ-AndSpeak })

# na stałe w PRAWYM DOLNYM rogu, zawsze na wierzchu (nie znika po kliknięciu)
$win.Topmost = $true
function Pin-Window {
    $wa = [Windows.SystemParameters]::WorkArea
    $win.Left = $wa.Right - $win.ActualWidth
    $win.Top  = $wa.Bottom - $win.ActualHeight
    $h = (New-Object Windows.Interop.WindowInteropHelper $win).Handle
    if ($h -ne [IntPtr]::Zero) { [void][PPJ]::SetWindowPos($h, [IntPtr](-1), 0, 0, 0, 0, 0x0013) }  # HWND_TOPMOST
}
$win.Add_Loaded({ Pin-Window })
$win.Add_Activated({ Pin-Window })
$win.Add_Deactivated({ Pin-Window })
$win.Add_SizeChanged({ Pin-Window })

Show-Quote $script:qi
$clock.Start(); $script:sysTimer.Start()   # $anim startuje dopiero gdy papież mówi
[void]$win.ShowDialog()
if ($script:syn) { $script:syn.Dispose() }
$mtx.ReleaseMutex()
