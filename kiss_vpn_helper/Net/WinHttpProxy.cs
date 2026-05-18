using System.Diagnostics;

namespace KissVPN.Helper.Net;

/// Manages the system-wide WinHTTP proxy via `netsh winhttp`.
///
/// Unlike the HKCU `Internet Settings` registry (which covers Chrome /
/// Edge / WinINet apps), WinHTTP is used by Windows Services, the
/// store delivery service, Office, PowerShell, etc. Setting it gives the
/// closest thing to TUN coverage we can offer without a working tunnel
/// driver — it requires admin, which is why it lives in the Helper.
public static class WinHttpProxy
{
    private const string DefaultBypass =
        "<local>;127.*;192.168.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;kissmain.ru;*.kissmain.ru";

    public static object Apply(string host, int port, string? bypass)
    {
        bypass ??= DefaultBypass;
        var out1 = Netsh($"winhttp set proxy proxy-server=\"{host}:{port}\" bypass-list=\"{bypass}\"");
        var out2 = Netsh("winhttp show proxy");
        return new
        {
            applied = true,
            host,
            port,
            bypass,
            show = out2.StdOut,
        };
    }

    public static object Reset()
    {
        var r = Netsh("winhttp reset proxy");
        return new { reset = true, output = r.StdOut };
    }

    private static (int ExitCode, string StdOut) Netsh(string args)
    {
        var psi = new ProcessStartInfo("netsh.exe", args)
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
            StandardOutputEncoding = System.Text.Encoding.UTF8,
        };
        var p = Process.Start(psi)!;
        var output = p.StandardOutput.ReadToEnd() + p.StandardError.ReadToEnd();
        p.WaitForExit();
        return (p.ExitCode, output);
    }
}
