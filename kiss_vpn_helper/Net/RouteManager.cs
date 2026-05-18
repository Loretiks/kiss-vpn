using System.Diagnostics;

namespace KissVPN.Helper.Net;

/// Adds / removes the catch-all IPv4 + IPv6 routes that pin the OS default
/// gateway to the TUN device Mihomo created.
///
/// We rely on Mihomo's `auto-route: true` for most cases — this is a manual
/// fallback for setups where auto-route doesn't catch everything (rare).
public static class RouteManager
{
    private static readonly List<(string Family, string Prefix)> KissRoutes = new()
    {
        ("ipv4", "0.0.0.0/1"),
        ("ipv4", "128.0.0.0/1"),
        ("ipv6", "::/1"),
        ("ipv6", "8000::/1"),
    };

    public static object RouteAllVia(Pipe.RouteArgs args)
    {
        if (string.IsNullOrWhiteSpace(args.InterfaceName))
            throw new ArgumentException("interface_name is required");

        foreach (var (family, prefix) in KissRoutes)
        {
            Netsh($"interface {family} add route {prefix} \"{args.InterfaceName}\" metric=1 store=active");
        }
        return new { added = KissRoutes.Count };
    }

    public static object ClearAll()
    {
        var n = 0;
        foreach (var (family, prefix) in KissRoutes)
        {
            // delete is idempotent — non-zero exit is fine when nothing to remove.
            var r = Netsh($"interface {family} delete route {prefix} store=active");
            if (r.ExitCode == 0) n++;
        }
        return new { removed = n };
    }

    private static (int ExitCode, string StdOut) Netsh(string args)
    {
        var psi = new ProcessStartInfo("netsh.exe", args)
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
        };
        var p = Process.Start(psi)!;
        var output = p.StandardOutput.ReadToEnd() + p.StandardError.ReadToEnd();
        p.WaitForExit();
        return (p.ExitCode, output);
    }
}
