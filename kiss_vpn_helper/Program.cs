using KissVPN.Helper.CoreLauncher;
using KissVPN.Helper.Pipe;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace KissVPN.Helper;

internal static class Program
{
    private const string ServiceName = "KissVPNHelper";

    public static int Main(string[] args)
    {
        if (args.Length > 0)
        {
            switch (args[0].ToLowerInvariant())
            {
                case "install":
                    return ServiceInstaller.Install(ServiceName);
                case "uninstall":
                    return ServiceInstaller.Uninstall(ServiceName);
                case "version":
                    Console.WriteLine("Kiss VPN Helper 0.1.0");
                    return 0;
            }
        }

        var builder = Host.CreateApplicationBuilder(args);
        builder.Services.AddWindowsService(opts =>
        {
            opts.ServiceName = ServiceName;
        });

        builder.Services.AddSingleton<MihomoSupervisor>();
        builder.Services.AddSingleton<RpcDispatcher>();
        builder.Services.AddHostedService<PipeServer>();

        builder.Logging.AddEventLog(settings =>
        {
            settings.SourceName = ServiceName;
        });

        var host = builder.Build();
        host.Run();
        return 0;
    }
}
