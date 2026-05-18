using System.Diagnostics;
using KissVPN.Helper.Pipe;

namespace KissVPN.Helper.Firewall;

/// Manages Windows Firewall rules for two concerns:
///   1. Kill switch — block all outbound traffic except for the VPN-related
///      executables (KissVPNCore.exe, KissVPNHelper.exe), so a core crash
///      doesn't leak traffic to the user's real network.
///   2. Inbound exceptions — let the bundled .exe files accept local loopback
///      from any Windows profile (otherwise SmartScreen prompts on first run).
public static class FirewallManager
{
    private const string KillRulePrefix = "KissVPN-Kill-";
    private const string AllowRulePrefix = "KissVPN-Allow-";
    private const string ExceptPrefix = "KissVPN-App-";

    public static object ApplyKillSwitch(KillswitchArgs args)
    {
        DropKillSwitch();
        if (!args.Enabled) return new { applied = false };

        Netsh($"advfirewall firewall add rule name=\"{KillRulePrefix}ALL\" dir=out action=block enable=yes profile=any");
        var allowed = args.AllowExecutables ?? Array.Empty<string>();
        foreach (var exe in allowed)
        {
            Netsh($"advfirewall firewall add rule name=\"{AllowRulePrefix}{Path.GetFileName(exe)}\" dir=out action=allow enable=yes profile=any program=\"{exe}\"");
        }
        // Always allow loopback so the UI ↔ core REST channel keeps working.
        Netsh($"advfirewall firewall add rule name=\"{AllowRulePrefix}Loopback\" dir=out action=allow enable=yes profile=any remoteip=127.0.0.1/8,::1/128");
        // Allow DHCP/DNS to local resolvers, otherwise initial sub refresh fails.
        Netsh($"advfirewall firewall add rule name=\"{AllowRulePrefix}DHCP\" dir=out action=allow enable=yes profile=any protocol=udp localport=68 remoteport=67");
        return new { applied = true, allow_count = allowed.Length };
    }

    public static object DropKillSwitch()
    {
        DeleteByPrefix(KillRulePrefix);
        DeleteByPrefix(AllowRulePrefix);
        return new { dropped = true };
    }

    public static object AddProductExceptions()
    {
        var exes = ProductExes();
        foreach (var (name, path) in exes)
        {
            if (!File.Exists(path)) continue;
            Netsh($"advfirewall firewall add rule name=\"{ExceptPrefix}{name}\" dir=in action=allow enable=yes profile=any program=\"{path}\"");
        }
        return new { added = exes.Count };
    }

    public static object RemoveProductExceptions()
    {
        DeleteByPrefix(ExceptPrefix);
        return new { removed = true };
    }

    private static List<(string Name, string Path)> ProductExes()
    {
        var dir = Path.GetDirectoryName(Environment.ProcessPath ?? "") ?? Environment.CurrentDirectory;
        return new()
        {
            ("App", Path.Combine(dir, "kiss_vpn.exe")),
            ("Core", Path.Combine(dir, "KissVPNCore.exe")),
            ("Helper", Path.Combine(dir, "KissVPNHelper.exe")),
        };
    }

    private static void DeleteByPrefix(string prefix)
    {
        // netsh `delete rule name=...` removes all matching, but only by exact
        // name. Enumerate first to support wildcard semantics.
        var psi = new ProcessStartInfo("netsh.exe", "advfirewall firewall show rule name=all")
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            CreateNoWindow = true,
            StandardOutputEncoding = System.Text.Encoding.UTF8,
        };
        var p = Process.Start(psi)!;
        var output = p.StandardOutput.ReadToEnd();
        p.WaitForExit();

        var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var line in output.Split('\n'))
        {
            // Expected: "Rule Name:           KissVPN-Kill-ALL"
            // The label is localised; do a startsWith check on the value side.
            var colon = line.IndexOf(':');
            if (colon < 0) continue;
            var value = line[(colon + 1)..].Trim();
            if (value.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                names.Add(value);
        }

        foreach (var name in names)
            Netsh($"advfirewall firewall delete rule name=\"{name}\"");
    }

    private static void Netsh(string args)
    {
        var psi = new ProcessStartInfo("netsh.exe", args)
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
        };
        var p = Process.Start(psi)!;
        _ = p.StandardOutput.ReadToEnd();
        _ = p.StandardError.ReadToEnd();
        p.WaitForExit();
    }
}
