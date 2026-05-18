using System.Text.Json;
using System.Text.Json.Serialization;

namespace KissVPN.Helper.Pipe;

/// JSON-RPC 2.0 request envelope.
public sealed record RpcRequest(
    [property: JsonPropertyName("jsonrpc")] string Jsonrpc,
    [property: JsonPropertyName("method")] string Method,
    [property: JsonPropertyName("params")] JsonElement? Params,
    [property: JsonPropertyName("id")] JsonElement? Id);

/// JSON-RPC 2.0 response envelope. Only one of [Result] / [Error] is set.
public sealed class RpcResponse
{
    [JsonPropertyName("jsonrpc")] public string Jsonrpc { get; init; } = "2.0";
    [JsonPropertyName("id")] public JsonElement? Id { get; init; }
    [JsonPropertyName("result")] public object? Result { get; init; }
    [JsonPropertyName("error")] public RpcError? Error { get; init; }

    public static RpcResponse Ok(JsonElement? id, object? result) =>
        new() { Id = id, Result = result ?? new { } };

    public static RpcResponse Fail(JsonElement? id, int code, string message) =>
        new() { Id = id, Error = new RpcError(code, message) };
}

public sealed record RpcError(
    [property: JsonPropertyName("code")] int Code,
    [property: JsonPropertyName("message")] string Message);
