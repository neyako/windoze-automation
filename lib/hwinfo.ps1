# Logs HWiNFO sensors to CSV by reading its shared memory. Works with free HWiNFO
# (needs "Shared Memory Support" enabled; free builds allow 12 h per session).

if (-not ('HwInfoLogger' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.IO.MemoryMappedFiles;
using System.Text;
using System.Threading;

// Layout: HWiNFO SDK, HWiNFO_SENSORS_SHARED_MEM2 (#pragma pack 1).
public class HwInfoLogger {
    const string MapName = "Global\\HWiNFO_SENS_SM2";
    readonly MemoryMappedFile map;
    readonly MemoryMappedViewAccessor view;
    readonly long readingOffset, readingSize;
    readonly object gate = new object();
    StreamWriter writer;
    Timer timer;
    double[] sum, max;
    double peakSum;
    long samples;

    public readonly string[] Columns;
    public readonly string[] Labels;
    public readonly int[] Types;   // 1 temp, 2 volt, 3 fan, 4 current, 5 power, 6 clock, 7 usage
    public string Phase = "";
    public int[] PeakSet = new int[0];   // readings whose per-sample max is averaged by PeakAvg (per-core clocks)

    public static int ReadingCount() {
        try {
            using (var m = MemoryMappedFile.OpenExisting(MapName, MemoryMappedFileRights.Read))
            using (var v = m.CreateViewAccessor(0, 0, MemoryMappedFileAccess.Read)) {
                return v.ReadUInt32(0) == 0x53695748 ? (int)v.ReadUInt32(40) : 0;   // "HWiS"
            }
        } catch { return 0; }
    }

    public HwInfoLogger() {
        map = MemoryMappedFile.OpenExisting(MapName, MemoryMappedFileRights.Read);
        view = map.CreateViewAccessor(0, 0, MemoryMappedFileAccess.Read);
        long sensorOffset = view.ReadUInt32(20), sensorSize = view.ReadUInt32(24);
        readingOffset = view.ReadUInt32(32);
        readingSize = view.ReadUInt32(36);
        int n = (int)view.ReadUInt32(40);
        Columns = new string[n]; Labels = new string[n]; Types = new int[n];
        for (int i = 0; i < n; i++) {
            long r = readingOffset + i * readingSize;
            int sensor = (int)view.ReadUInt32(r + 4);
            Types[i] = (int)view.ReadUInt32(r);
            Labels[i] = Str(r + 12, 128);
            Columns[i] = Str(sensorOffset + sensor * sensorSize + 8, 128) + "|" + Labels[i] + " [" + Str(r + 268, 16) + "]";
        }
        var seen = new Dictionary<string, int>();   // some sensors repeat a name; Import-Csv rejects duplicate headers
        for (int i = 0; i < n; i++) {
            int count;
            seen.TryGetValue(Columns[i], out count);
            seen[Columns[i]] = ++count;
            if (count > 1) Columns[i] += " #" + count;
        }
        ResetStats();
    }

    string Str(long pos, int len) {
        var b = new byte[len];
        view.ReadArray(pos, b, 0, len);
        int end = Array.IndexOf(b, (byte)0);
        return Encoding.Default.GetString(b, 0, end < 0 ? len : end).Trim();
    }

    public void ResetStats() {
        lock (gate) {
            sum = new double[Columns.Length]; max = new double[Columns.Length]; samples = 0; peakSum = 0;
            for (int i = 0; i < max.Length; i++) max[i] = double.MinValue;
        }
    }

    public void Start(string path, int intervalMs) {
        writer = new StreamWriter(path, false, new UTF8Encoding(false));
        writer.AutoFlush = true;
        var head = new StringBuilder("Time,Phase");
        foreach (var c in Columns) head.Append(",\"").Append(c.Replace("\"", "'")).Append('"');
        writer.WriteLine(head);
        timer = new Timer(Tick, null, 0, intervalMs);
    }

    void Tick(object _) {
        try {
            lock (gate) {
                if (writer == null) return;
                var line = new StringBuilder(DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture));
                line.Append(',').Append(Phase);
                for (int i = 0; i < Columns.Length; i++) {
                    double v = view.ReadDouble(readingOffset + i * readingSize + 284);
                    sum[i] += v;
                    if (v > max[i]) max[i] = v;
                    line.Append(',').Append(v.ToString("0.###", CultureInfo.InvariantCulture));
                }
                double peak = 0;
                foreach (int i in PeakSet) peak = Math.Max(peak, view.ReadDouble(readingOffset + i * readingSize + 284));
                peakSum += peak;
                samples++;
                writer.WriteLine(line);
            }
        } catch { }
    }

    public void Stop() {
        if (timer != null) timer.Dispose();
        lock (gate) { if (writer != null) { writer.Dispose(); writer = null; } }
    }

    // First reading whose label matches one of the candidates (in order) with the given type, or -1.
    public int Find(int type, params string[] labels) {
        foreach (var l in labels)
            for (int i = 0; i < Labels.Length; i++)
                if (Types[i] == type && string.Equals(Labels[i], l, StringComparison.OrdinalIgnoreCase)) return i;
        return -1;
    }

    public double Avg(int i) { lock (gate) { return i < 0 || samples == 0 ? double.NaN : Math.Round(sum[i] / samples, 1); } }
    public double PeakAvg() { lock (gate) { return PeakSet.Length == 0 || samples == 0 ? double.NaN : Math.Round(peakSum / samples, 1); } }
    public double Max(int i) { lock (gate) { return i < 0 || samples == 0 ? double.NaN : Math.Round(max[i], 1); } }
}
'@
}

function Start-HwInfoLogger {
    if ([HwInfoLogger]::ReadingCount() -eq 0) {
        $exe = "$BenchRoot\tools\HWiNFO\HWiNFO64.exe"
        if (-not (Test-Path $exe)) { throw "HWiNFO not found at $exe" }
        if (-not (Get-Process HWiNFO64 -ErrorAction SilentlyContinue)) { Start-Process $exe; $script:HwInfoStarted = $true }   # caller closes it
        Write-Host 'Waiting for HWiNFO sensors...'
        $deadline = (Get-Date).AddSeconds(90)
        while ([HwInfoLogger]::ReadingCount() -eq 0) {
            if ((Get-Date) -gt $deadline) {
                throw 'No HWiNFO shared memory. In HWiNFO settings enable "Sensors-only" and "Shared Memory Support".'
            }
            Start-Sleep 2
        }
        Start-Sleep 5   # let every sensor report once
    }
    New-Object HwInfoLogger
}
