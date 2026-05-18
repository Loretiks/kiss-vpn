using System.Diagnostics;

namespace KissVPN.Helper;

/// Installs / removes Kiss VPN Helper as a Windows Service via `sc.exe`.
///
/// The service runs as LocalSystem so it can manage routes, DNS, the
/// firewall, and Wintun. The pipe ACL (see <see cref="Pipe.PipeServer"/>)
/// is what gates which user-space accounts can call its methods.
internal static class ServiceInstaller
{
    public static int Install(string serviceName)
    {
        var exe = Environment.ProcessPath
            ?? throw new InvalidOperationException("Cannot resolve helper path");

        var run = Sc($"create {serviceName} binPath= \"{exe}\" start= auto type= own DisplayName= \"Kiss VPN Helper\"");
        if (run.ExitCode != 0 && !run.StdOut.Contains("1073"))
        {
            Console.Error.WriteLine(run.StdOut);
            Console.Error.WriteLine(run.StdErr);
            return run.ExitCode;
        }

        Sc($"description {serviceName} \"Privileged broker for Kiss VPN — runs the proxy core and manages TUN, routes, DNS and the firewall.\"");
        Sc($"failure {serviceName} reset= 86400 actions= restart/3000/restart/5000/restart/10000");
        Sc($"start {serviceName}");
        Console.WriteLine($"Service {serviceName} installed and started.");
        return 0;
    }

    public static int Uninstall(string serviceName)
    {
        Sc($"stop {serviceName}");
        var r = Sc($"delete {serviceName}");
        if (r.ExitCode != 0)
        {
            Console.Error.WriteLine(r.StdOut);
            Console.Error.WriteLine(r.StdErr);
            return r.ExitCode;
        }
        Console.WriteLine($"Service {serviceName} removed.");
        return 0;
    }

    private static (int ExitCode, string StdOut, string StdErr) Sc(string args)
    {
        var psi = new ProcessStartInfo("sc.exe", args)
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
        };
        var p = Process.Start(psi)!;
        var stdout = p.StandardOutput.ReadToEnd();
        var stderr = p.StandardError.ReadToEnd();
        p.WaitForExit();
        return (p.ExitCode, stdout, stderr);
    }
}
