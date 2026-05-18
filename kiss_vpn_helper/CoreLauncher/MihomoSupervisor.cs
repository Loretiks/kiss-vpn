using System.Diagnostics;
using System.Text;
using KissVPN.Helper.Pipe;
using Microsoft.Extensions.Logging;

namespace KissVPN.Helper.CoreLauncher;

/// Owns the lifetime of the Mihomo process spawned on behalf of the UI.
/// One instance per service host — the supervisor enforces single-running
/// invariant (UI can only have one active core at a time).
public sealed class MihomoSupervisor
{
    private readonly ILogger<MihomoSupervisor> _log;
    private readonly object _gate = new();
    private Process? _proc;
    private readonly StringBuilder _logBuffer = new();
    private const int LogBufferMax = 64 * 1024;

    public MihomoSupervisor(ILogger<MihomoSupervisor> log) => _log = log;

    public object Status()
    {
        lock (_gate)
        {
            var alive = _proc != null && !_proc.HasExited;
            return new
            {
                running = alive,
                pid = alive ? _proc!.Id : (int?)null,
                started_at = alive ? _proc!.StartTime.ToUniversalTime() : (DateTime?)null,
            };
        }
    }

    public async Task<object> StartAsync(StartArgs args, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(args.CorePath) || !File.Exists(args.CorePath))
            throw new FileNotFoundException($"Core binary not found at {args.CorePath}");
        if (string.IsNullOrWhiteSpace(args.ConfigPath) || !File.Exists(args.ConfigPath))
            throw new FileNotFoundException($"Config not found at {args.ConfigPath}");

        await StopAsync(ct);
        // Hunt down orphaned KissVPNCore.exe instances that survived a
        // previous Helper crash / restart. Without this, the new spawn
        // would silently hit `address already in use` on 9090/7890 and
        // the user would see a stale (or empty) status forever.
        KillOrphans(args.CorePath);

        var workDir = args.WorkDir ?? Path.GetDirectoryName(args.ConfigPath)!;
        var psi = new ProcessStartInfo
        {
            FileName = args.CorePath,
            WorkingDirectory = workDir,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
        };
        psi.ArgumentList.Add("-d");
        psi.ArgumentList.Add(workDir);
        psi.ArgumentList.Add("-f");
        psi.ArgumentList.Add(args.ConfigPath);

        var proc = new Process { StartInfo = psi, EnableRaisingEvents = true };
        proc.OutputDataReceived += (_, e) => AppendLog(e.Data);
        proc.ErrorDataReceived += (_, e) => AppendLog(e.Data, isStderr: true);
        proc.Exited += (_, _) =>
        {
            _log.LogInformation("Mihomo exited (code={Code})", proc.ExitCode);
        };

        proc.Start();
        proc.BeginOutputReadLine();
        proc.BeginErrorReadLine();

        lock (_gate)
        {
            _proc = proc;
            _logBuffer.Clear();
        }

        // Wait briefly for OUR REST API to come up. A plain TCP connect to
        // 9090 — or even an HTTP /version — isn't enough: SnowVPN, FlClash
        // and v2rayN all ship Mihomo variants that bind 9090 by default.
        // We could end up green-lighting a session that never attached to
        // our process. So in addition to the HTTP probe we check that the
        // socket on 9090 is owned by OUR child PID.
        var deadline = DateTime.UtcNow.AddSeconds(12);
        using var http = new System.Net.Http.HttpClient
        {
            Timeout = TimeSpan.FromSeconds(2),
        };
        while (DateTime.UtcNow < deadline)
        {
            if (proc.HasExited)
            {
                var tail2 = SnapshotLog();
                throw new InvalidOperationException(
                    "Mihomo exited before it could bind 127.0.0.1:9090. " +
                    "Скорее всего, порт занят другим VPN-клиентом " +
                    "(SnowVPN, FlClash, v2rayN…). Закройте его и попробуйте снова." +
                    "\n--- core log tail ---\n" + tail2);
            }
            try
            {
                var r = await http.GetStringAsync("http://127.0.0.1:9090/version", ct);
                if (r.Contains("\"version\"", StringComparison.OrdinalIgnoreCase))
                {
                    var ownerPid = TryGetListenerPid(9090);
                    if (ownerPid != proc.Id)
                    {
                        _log.LogWarning(
                            "Port 9090 is owned by pid {Owner}, not our child pid {Child} — likely another VPN client. Aborting.",
                            ownerPid, proc.Id);
                        await StopAsync(ct);
                        throw new InvalidOperationException(
                            $"Порт 127.0.0.1:9090 уже занят другим VPN-клиентом (pid {ownerPid}). " +
                            "Закройте SnowVPN / FlClash / v2rayN и попробуйте снова.");
                    }
                    _log.LogInformation("Mihomo ready, pid={Pid} version={Body}", proc.Id, r);
                    return new { running = true, pid = proc.Id, version_response = r };
                }
            }
            catch (InvalidOperationException) { throw; }
            catch { /* not ready yet */ }
            await Task.Delay(250, ct);
        }

        // REST never came up — capture log tail and tear down.
        var tail = SnapshotLog();
        var exited = proc.HasExited;
        var exitCode = exited ? proc.ExitCode : (int?)null;
        await StopAsync(ct);

        var hint = "";
        if (exited)
        {
            hint = exitCode == -1073741819 || tail.Contains("address already in use")
                ? "\n\nПохоже, что порт 9090 или 7890 занят другим VPN-клиентом " +
                  "(SnowVPN, FlClash, v2rayN…). Закройте его и попробуйте снова."
                : "\n\nMihomo завершился с кодом " + exitCode + ". Проверьте лог ядра.";
        }
        throw new InvalidOperationException(
            $"Mihomo started but REST API did not come up within 12s.{hint}\n--- core log tail ---\n{tail}");
    }

    public async Task StopAsync(CancellationToken ct)
    {
        Process? proc;
        lock (_gate)
        {
            proc = _proc;
            _proc = null;
        }
        if (proc == null) return;
        if (proc.HasExited) return;

        try
        {
            // SIGTERM equivalent on Windows = WM_CLOSE for windowed apps,
            // CtrlC for consoles. Mihomo handles WM_CLOSE → graceful.
            proc.CloseMainWindow();
            await Task.WhenAny(proc.WaitForExitAsync(ct), Task.Delay(3000, ct));
            if (!proc.HasExited) proc.Kill(entireProcessTree: true);
        }
        catch (Exception ex)
        {
            _log.LogWarning(ex, "Stop failed, trying kill");
            try { proc.Kill(entireProcessTree: true); } catch { /* swallow */ }
        }
        finally
        {
            proc.Dispose();
        }
    }

    public string SnapshotLog()
    {
        lock (_gate) return _logBuffer.ToString();
    }

    /// Returns the PID of the process listening on `127.0.0.1:<port>`, or
    /// -1 if no such listener exists. Uses GetExtendedTcpTable so we can
    /// associate each socket with its owning process — required to tell
    /// "our Mihomo bound 9090" from "some other VPN client beat us to it".
    private static int TryGetListenerPid(int port)
    {
        try
        {
            return KissVPN.Helper.Net.PortOwner.Of(port);
        }
        catch
        {
            return -1;
        }
    }

    /// Best-effort cleanup of stale `KissVPNCore.exe` processes left over
    /// from a previous Helper instance (which may have crashed or been
    /// restarted). We only consider processes that point at the same
    /// executable path we're about to launch — that keeps us from blowing
    /// away unrelated copies the user might be testing manually.
    private void KillOrphans(string corePath)
    {
        try
        {
            var name = Path.GetFileNameWithoutExtension(corePath);
            foreach (var p in Process.GetProcessesByName(name))
            {
                try
                {
                    string? mainModule = null;
                    try { mainModule = p.MainModule?.FileName; } catch { /* access denied */ }
                    if (mainModule == null ||
                        string.Equals(mainModule, corePath, StringComparison.OrdinalIgnoreCase))
                    {
                        _log.LogWarning("Killing orphan {Name} pid={Pid}", name, p.Id);
                        p.Kill(entireProcessTree: true);
                        try { p.WaitForExit(2000); } catch { /* swallow */ }
                    }
                }
                catch (Exception ex)
                {
                    _log.LogWarning(ex, "Could not kill orphan {Name} pid={Pid}", name, p.Id);
                }
                finally { p.Dispose(); }
            }
        }
        catch (Exception ex)
        {
            _log.LogWarning(ex, "Orphan scan failed");
        }
    }

    private void AppendLog(string? line, bool isStderr = false)
    {
        if (line == null) return;
        lock (_gate)
        {
            if (_logBuffer.Length > LogBufferMax)
                _logBuffer.Remove(0, _logBuffer.Length - LogBufferMax + 1024);
            if (isStderr) _logBuffer.Append("[stderr] ");
            _logBuffer.AppendLine(line);
        }
    }
}
