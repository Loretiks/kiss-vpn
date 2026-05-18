using System.Diagnostics;
using System.Net.NetworkInformation;
using Microsoft.Win32;

namespace KissVPN.Helper.Net;

/// Switches every active (non-loopback) IPv4 adapter to use the supplied DNS
/// servers, recording the prior state under
/// HKLM\SOFTWARE\KissVPN\DnsBackup so it can be restored on Disconnect.
public static class DnsManager
{
    private const string BackupRoot = @"SOFTWARE\KissVPN\DnsBackup";

    public static object SetDns(string[] servers)
    {
        var changed = new List<string>();
        foreach (var nic in NetworkInterface.GetAllNetworkInterfaces())
        {
            if (nic.OperationalStatus != OperationalStatus.Up) continue;
            if (nic.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;
            if (nic.NetworkInterfaceType == NetworkInterfaceType.Tunnel) continue;

            BackupOriginal(nic);

            // `set dnsservers` replaces all entries on the interface.
            var first = servers.Length > 0 ? servers[0] : "1.1.1.1";
            Netsh($"interface ipv4 set dnsservers name=\"{nic.Name}\" source=static address={first} register=primary validate=no");
            for (var i = 1; i < servers.Length; i++)
            {
                Netsh($"interface ipv4 add dnsservers name=\"{nic.Name}\" address={servers[i]} index={i + 1} validate=no");
            }
            changed.Add(nic.Name);
        }
        return new { changed };
    }

    public static object Restore()
    {
        using var root = Registry.LocalMachine.OpenSubKey(BackupRoot, writable: true);
        if (root == null) return new { restored = 0 };

        var restored = 0;
        foreach (var name in root.GetValueNames())
        {
            var raw = root.GetValue(name)?.ToString();
            if (string.IsNullOrEmpty(raw)) continue;
            // raw = "dhcp" or "1.1.1.1,8.8.8.8"
            if (raw == "dhcp")
            {
                Netsh($"interface ipv4 set dnsservers name=\"{name}\" source=dhcp");
            }
            else
            {
                var ips = raw.Split(',', StringSplitOptions.RemoveEmptyEntries);
                if (ips.Length > 0)
                {
                    Netsh($"interface ipv4 set dnsservers name=\"{name}\" source=static address={ips[0]} register=primary validate=no");
                    for (var i = 1; i < ips.Length; i++)
                        Netsh($"interface ipv4 add dnsservers name=\"{name}\" address={ips[i]} index={i + 1} validate=no");
                }
            }
            root.DeleteValue(name, throwOnMissingValue: false);
            restored++;
        }
        return new { restored };
    }

    private static void BackupOriginal(NetworkInterface nic)
    {
        using var root = Registry.LocalMachine.CreateSubKey(BackupRoot);
        // Don't overwrite an existing backup — we want the *original* state.
        if (root.GetValue(nic.Name) != null) return;

        var props = nic.GetIPProperties();
        var dns = string.Join(',',
            props.DnsAddresses.Where(a => a.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork)
                .Select(a => a.ToString()));
        // Heuristic: if DnsAddresses are auto-assigned the interface had dhcp.
        // We can't reliably detect that without IpHelper P/Invoke, so we fall
        // back to recording the literal list — restore via `set static` works
        // in both cases.
        root.SetValue(nic.Name, dns.Length == 0 ? "dhcp" : dns);
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
