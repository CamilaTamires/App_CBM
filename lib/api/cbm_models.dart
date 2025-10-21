// lib/api/cbm_models.dart
// ===============================================================
// MODELOS DE DADOS
// ===============================================================

class CustomUser {
  final int id;
  final String username;

  CustomUser({required this.id, required this.username});

  factory CustomUser.fromJson(Map<String, dynamic> json) {
    return CustomUser(
      id: json['id'] ?? 0,
      // backend pode mandar "name" ou "username"
      username: json['name'] ?? json['username'] ?? 'Sem nome',
    );
  }

  @override
  String toString() => 'User(id: $id, username: $username)';
}

class EnvironmentRef {
  final int id;
  final String name;

  EnvironmentRef({required this.id, required this.name});

  factory EnvironmentRef.fromJson(Map<String, dynamic> json) {
    return EnvironmentRef(id: json['id'] ?? 0, name: json['name'] ?? '');
  }
}

class Equipment {
  final int id;
  final String name;
  final String? code;
  final String? description;
  final String? qrCodeImage;
  final EnvironmentRef? environment; // <-- environment_FK

  Equipment({
    required this.id,
    required this.name,
    this.code,
    this.description,
    this.qrCodeImage,
    this.environment,
  });

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Sem nome',
      code: json['code'] as String?,
      description: json['description'] as String?,
      qrCodeImage: json['qr_code_image'] as String?,
      environment: (json['environment_FK'] is Map<String, dynamic>)
          ? EnvironmentRef.fromJson(json['environment_FK'])
          : null,
    );
  }

  @override
  String toString() =>
      'Equipment(id: $id, name: $name, env: ${environment?.name})';
}
