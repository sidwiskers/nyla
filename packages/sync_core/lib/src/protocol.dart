import 'dart:convert';

String base64UrlNoPadding(List<int> bytes) => base64UrlEncode(bytes).replaceAll('=', '');

List<int> decodeBase64UrlNoPadding(String value) {
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
    throw const FormatException('Invalid base64url data');
  }
  return base64Url.decode(base64Url.normalize(value));
}

final class SyncKeyMaterial {
  const SyncKeyMaterial({
    required this.vaultId,
    required this.deviceId,
    required this.epoch,
    required this.vaultKey,
    required this.signingSeed,
    required this.exchangeSeed,
  });

  final String vaultId;
  final String deviceId;
  final int epoch;
  final List<int> vaultKey;
  final List<int> signingSeed;
  final List<int> exchangeSeed;

  void validate() {
    if (!RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(vaultId) ||
        !RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(deviceId)) {
      throw const FormatException('Invalid sync identity');
    }
    if (epoch < 1 || vaultKey.length != 32 || signingSeed.length != 32 || exchangeSeed.length != 32) {
      throw const FormatException('Invalid sync key material');
    }
  }
}

final class SyncPublicIdentity {
  const SyncPublicIdentity({
    required this.signingPublicKey,
    required this.exchangePublicKey,
  });

  final List<int> signingPublicKey;
  final List<int> exchangePublicKey;
}

final class SyncPlainOperation {
  const SyncPlainOperation({
    required this.opId,
    required this.entityId,
    required this.entityType,
    required this.field,
    required this.hlc,
    required this.kind,
    this.value,
  });

  final String opId;
  final String entityId;
  final String entityType;
  final String field;
  final String hlc;
  final String kind;
  final Object? value;

  List<int> canonicalBytes() => utf8.encode(jsonEncode(<String, Object?>{
        'v': 1,
        'op': opId,
        'entity': entityId,
        'entity_type': entityType,
        'field': field,
        'hlc': hlc,
        'kind': kind,
        'value': value,
      }));

  factory SyncPlainOperation.decode(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic> || decoded['v'] != 1) {
      throw const FormatException('Unsupported sync operation');
    }
    final opId = decoded['op'];
    final entityId = decoded['entity'];
    final entityType = decoded['entity_type'];
    final field = decoded['field'];
    final hlc = decoded['hlc'];
    final kind = decoded['kind'];
    if (opId is! String ||
        entityId is! String ||
        entityType is! String ||
        field is! String ||
        hlc is! String ||
        kind is! String ||
        !const {'set', 'unset', 'delete'}.contains(kind)) {
      throw const FormatException('Malformed sync operation');
    }
    return SyncPlainOperation(
      opId: opId,
      entityId: entityId,
      entityType: entityType,
      field: field,
      hlc: hlc,
      kind: kind,
      value: decoded['value'],
    );
  }
}

final class SyncEnvelope {
  const SyncEnvelope({
    required this.vaultId,
    required this.deviceId,
    required this.epoch,
    required this.opId,
    required this.nonce,
    required this.ciphertextAndMac,
    required this.signature,
  });

  final String vaultId;
  final String deviceId;
  final int epoch;
  final String opId;
  final List<int> nonce;
  final List<int> ciphertextAndMac;
  final List<int> signature;

  String get nonceEncoded => base64UrlNoPadding(nonce);
  String get ciphertextEncoded => base64UrlNoPadding(ciphertextAndMac);
  String get signatureEncoded => base64UrlNoPadding(signature);

  Map<String, Object> uploadJson() => {
        'v': 1,
        'op': opId,
        'epoch': epoch,
        'nonce': nonceEncoded,
        'ciphertext': ciphertextEncoded,
        'signature': signatureEncoded,
      };

  List<int> signaturePayload() => utf8.encode([
        'nyla-envelope-v1',
        vaultId,
        deviceId,
        '$epoch',
        opId,
        nonceEncoded,
        ciphertextEncoded,
      ].join('\n'));

  List<int> aad() => utf8.encode('nyla-sync-v1|$vaultId|$deviceId|$opId');
}

List<int> bootstrapPayload({
  required String vaultId,
  required String deviceId,
  required String signingPublicKey,
  required String exchangePublicKey,
  required String timestamp,
  required String nonce,
}) =>
    utf8.encode([
      'nyla-bootstrap-v1',
      vaultId,
      deviceId,
      signingPublicKey,
      exchangePublicKey,
      timestamp,
      nonce,
    ].join('\n'));

List<int> httpAuthPayload({
  required String method,
  required String canonicalPath,
  required String timestamp,
  required String nonce,
  required String bodyHash,
}) =>
    utf8.encode([
      'nyla-http-v1',
      method.toUpperCase(),
      canonicalPath,
      timestamp,
      nonce,
      bodyHash,
    ].join('\n'));
