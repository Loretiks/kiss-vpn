using System.IO.Pipes;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace KissVPN.Helper.Pipe;

/// Hosts the named pipe `\\.\pipe\KissVPN.Helper`. Accepts JSON-RPC 2.0
/// requests, dispatches via <see cref="RpcDispatcher"/>, sends responses
/// back. Multiple concurrent clients are supported via per-connection
/// async tasks; each connection lives until the client closes the handle.
public sealed class PipeServer(ILogger<PipeServer> log, RpcDispatcher rpc) : BackgroundService
{
    public const string PipeName = "KissVPN.Helper";

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
        DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull,
    };

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        log.LogInformation("PipeServer starting at \\\\.\\pipe\\{Name}", PipeName);
        while (!stoppingToken.IsCancellationRequested)
        {
            NamedPipeServerStream? pipe = null;
            try
            {
                pipe = CreatePipe();
                await pipe.WaitForConnectionAsync(stoppingToken);
                _ = HandleClientAsync(pipe, stoppingToken);
            }
            catch (OperationCanceledException) { /* shutdown */ }
            catch (Exception ex)
            {
                log.LogError(ex, "Pipe accept failed");
                pipe?.Dispose();
                await Task.Delay(500, stoppingToken);
            }
        }
    }

    private async Task HandleClientAsync(NamedPipeServerStream pipe, CancellationToken ct)
    {
        try
        {
            using var reader = new StreamReader(pipe, Encoding.UTF8, leaveOpen: true);
            using var writer = new StreamWriter(pipe, new UTF8Encoding(false))
            {
                AutoFlush = true,
                NewLine = "\n",
            };

            while (pipe.IsConnected && !ct.IsCancellationRequested)
            {
                string? line = await reader.ReadLineAsync(ct);
                if (line == null) break;
                line = line.Trim();
                if (line.Length == 0) continue;

                RpcResponse response;
                RpcRequest? request = null;
                try
                {
                    request = JsonSerializer.Deserialize<RpcRequest>(line, JsonOpts);
                    if (request == null || string.IsNullOrEmpty(request.Method))
                    {
                        response = RpcResponse.Fail(null, -32600, "Invalid request");
                    }
                    else
                    {
                        response = await rpc.DispatchAsync(request, ct);
                    }
                }
                catch (JsonException jx)
                {
                    response = RpcResponse.Fail(null, -32700, $"Parse error: {jx.Message}");
                }
                catch (Exception ex)
                {
                    log.LogError(ex, "RPC dispatch failed for {Method}", request?.Method);
                    response = RpcResponse.Fail(request?.Id, -32000, ex.Message);
                }

                await writer.WriteLineAsync(JsonSerializer.Serialize(response, JsonOpts));
            }
        }
        catch (Exception ex)
        {
            log.LogWarning(ex, "Pipe client errored");
        }
        finally
        {
            try { pipe.Disconnect(); } catch { /* best-effort */ }
            pipe.Dispose();
        }
    }

    /// Creates a pipe that allows access only to the calling user account
    /// and the Administrators group. SYSTEM (the service host) is implicitly
    /// allowed as the pipe owner.
    private static NamedPipeServerStream CreatePipe()
    {
        var security = new PipeSecurity();
        var owner = WindowsIdentity.GetCurrent().Owner;
        if (owner != null)
        {
            security.SetOwner(owner);
            security.AddAccessRule(new PipeAccessRule(owner, PipeAccessRights.FullControl, AccessControlType.Allow));
        }
        security.AddAccessRule(new PipeAccessRule(
            new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null),
            PipeAccessRights.FullControl, AccessControlType.Allow));
        security.AddAccessRule(new PipeAccessRule(
            new SecurityIdentifier(WellKnownSidType.InteractiveSid, null),
            PipeAccessRights.ReadWrite | PipeAccessRights.CreateNewInstance | PipeAccessRights.Synchronize,
            AccessControlType.Allow));

        var pipe = NamedPipeServerStreamAcl.Create(
            pipeName: PipeName,
            direction: PipeDirection.InOut,
            maxNumberOfServerInstances: NamedPipeServerStream.MaxAllowedServerInstances,
            transmissionMode: PipeTransmissionMode.Byte,
            options: PipeOptions.Asynchronous,
            inBufferSize: 64 * 1024,
            outBufferSize: 64 * 1024,
            pipeSecurity: security);

        return pipe;
    }
}
