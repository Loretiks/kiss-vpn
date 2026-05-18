using System.Security.Principal;
using System.Text.Json;
using KissVPN.Helper.CoreLauncher;
using KissVPN.Helper.Firewall;
using KissVPN.Helper.Net;
using Microsoft.Extensions.Logging;

namespace KissVPN.Helper.Pipe;

/// Dispatches JSON-RPC method names to handler delegates. Centralising
/// routing here keeps <see cref="PipeServer"/> free of business logic.
public sealed class RpcDispatcher
{
    private readonly ILogger<RpcDispatcher> _log;
    private readonly MihomoSupervisor _mihomo;

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
    };

    public RpcDispatcher(ILogger<RpcDispatcher> log, MihomoSupervisor mihomo)
    {
        _log = log;
        _mihomo = mihomo;
    }

    public async Task<RpcResponse> DispatchAsync(RpcRequest req, CancellationToken ct)
    {
        _log.LogInformation("RPC {Method}", req.Method);

        try
        {
            return req.Method switch
            {
                "ping" => RpcResponse.Ok(req.Id, new { pong = true, ts = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() }),
                "version" => RpcResponse.Ok(req.Id, new
                {
                    version = "0.1.0",
                    is_elevated = IsElevated(),
                }),

                // Core lifecycle ----------------------------------------------
                "start_vpn" => RpcResponse.Ok(req.Id,
                    await StartVpnAsync(req.Params, ct)),
                "stop_vpn" => RpcResponse.Ok(req.Id, await StopVpnAsync(ct)),
                "core_status" => RpcResponse.Ok(req.Id, _mihomo.Status()),
                "core_logs" => RpcResponse.Ok(req.Id, new { log = _mihomo.SnapshotLog() }),

                // TUN + routes ------------------------------------------------
                "set_routes" => RpcResponse.Ok(req.Id, SetRoutes(req.Params)),
                "clear_routes" => RpcResponse.Ok(req.Id, RouteManager.ClearAll()),
                "set_dns" => RpcResponse.Ok(req.Id, SetDns(req.Params)),
                "restore_dns" => RpcResponse.Ok(req.Id, DnsManager.Restore()),

                // WinHTTP system proxy — covers Windows services, Office, etc.
                // beyond HKCU Internet Settings. Helper-only because netsh
                // winhttp requires admin.
                "set_winhttp_proxy" => RpcResponse.Ok(req.Id, SetWinHttp(req.Params)),
                "reset_winhttp_proxy" => RpcResponse.Ok(req.Id, Net.WinHttpProxy.Reset()),

                // Firewall / killswitch --------------------------------------
                "apply_killswitch" => RpcResponse.Ok(req.Id, ApplyKillswitch(req.Params)),
                "drop_killswitch" => RpcResponse.Ok(req.Id, FirewallManager.DropKillSwitch()),
                "add_firewall_exceptions" => RpcResponse.Ok(req.Id, FirewallManager.AddProductExceptions()),
                "remove_firewall_exceptions" => RpcResponse.Ok(req.Id, FirewallManager.RemoveProductExceptions()),

                _ => RpcResponse.Fail(req.Id, -32601, $"Unknown method: {req.Method}"),
            };
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Method {Method} failed", req.Method);
            return RpcResponse.Fail(req.Id, -32000, ex.Message);
        }
    }

    private async Task<object> StartVpnAsync(JsonElement? p, CancellationToken ct)
    {
        var args = Parse<StartArgs>(p) ?? throw new ArgumentException("start_vpn requires { core_path, config_path, tun }");
        return await _mihomo.StartAsync(args, ct);
    }

    private async Task<object> StopVpnAsync(CancellationToken ct)
    {
        await _mihomo.StopAsync(ct);
        return new { stopped = true };
    }

    private static object SetRoutes(JsonElement? p)
    {
        var args = Parse<RouteArgs>(p) ?? throw new ArgumentException("set_routes requires { interface_name, gateway }");
        return RouteManager.RouteAllVia(args);
    }

    private static object SetDns(JsonElement? p)
    {
        var args = Parse<DnsArgs>(p) ?? throw new ArgumentException("set_dns requires { servers }");
        return DnsManager.SetDns(args.Servers ?? Array.Empty<string>());
    }

    private static object SetWinHttp(JsonElement? p)
    {
        var args = Parse<WinHttpArgs>(p) ?? throw new ArgumentException("set_winhttp_proxy requires { host, port }");
        return Net.WinHttpProxy.Apply(args.Host ?? "127.0.0.1", args.Port ?? 7890, args.Bypass);
    }

    private static object ApplyKillswitch(JsonElement? p)
    {
        var args = Parse<KillswitchArgs>(p) ?? new KillswitchArgs();
        return FirewallManager.ApplyKillSwitch(args);
    }

    private static T? Parse<T>(JsonElement? p)
    {
        if (p == null || p.Value.ValueKind == JsonValueKind.Null) return default;
        return p.Value.Deserialize<T>(JsonOpts);
    }

    private static bool IsElevated()
    {
        try
        {
            using var identity = WindowsIdentity.GetCurrent();
            var principal = new WindowsPrincipal(identity);
            return principal.IsInRole(WindowsBuiltInRole.Administrator);
        }
        catch
        {
            return false;
        }
    }
}

public sealed class StartArgs
{
    public string CorePath { get; set; } = "";
    public string ConfigPath { get; set; } = "";
    public string? WorkDir { get; set; }
    public bool Tun { get; set; }
}

public sealed class RouteArgs
{
    public string? InterfaceName { get; set; }
    public string? Gateway { get; set; }
}

public sealed class DnsArgs
{
    public string[]? Servers { get; set; }
}

public sealed class KillswitchArgs
{
    /// Names of executables that are allowed to escape the kill switch
    /// (typically KissVPNCore.exe + KissVPNHelper.exe themselves).
    public string[]? AllowExecutables { get; set; }
    public bool Enabled { get; set; } = true;
}

public sealed class WinHttpArgs
{
    public string? Host { get; set; }
    public int? Port { get; set; }
    public string? Bypass { get; set; }
}
