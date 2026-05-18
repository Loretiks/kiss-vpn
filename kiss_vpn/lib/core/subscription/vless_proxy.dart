/// In-memory representation of a single VLESS server, decoded from a
/// `vless://` URL. Field names match Mihomo's clash-meta YAML schema where
/// applicable, with original VLESS terminology preserved for the rest.
class VlessProxy {
  const VlessProxy({
    required this.name,
    required this.uuid,
    required this.server,
    required this.port,
    required this.network, // tcp | ws | grpc | h2
    this.encryption = 'none',
    this.flow,                // e.g. xtls-rprx-vision
    this.tls = false,         // tls=true if security is "tls" or "reality"
    this.security,            // none | tls | reality
    this.sni,                 // servername
    this.fingerprint,         // client-fingerprint: chrome
    this.realityPublicKey,    // pbk
    this.realityShortId,      // sid
    this.realitySpiderX,      // spx
    this.alpn,
    this.wsPath,
    this.wsHost,
    this.grpcServiceName,
  });

  final String name;
  final String uuid;
  final String server;
  final int port;
  final String network;
  final String encryption;
  final String? flow;
  final bool tls;
  final String? security;
  final String? sni;
  final String? fingerprint;
  final String? realityPublicKey;
  final String? realityShortId;
  final String? realitySpiderX;
  final String? alpn;
  final String? wsPath;
  final String? wsHost;
  final String? grpcServiceName;

  Map<String, dynamic> toJson() => {
        'name': name,
        'uuid': uuid,
        'server': server,
        'port': port,
        'network': network,
        'security': security,
        'sni': sni,
        'flow': flow,
        'fingerprint': fingerprint,
      };
}
