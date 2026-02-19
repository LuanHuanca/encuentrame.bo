/// Modelo de usuario (alineado con la API /api/me/bootstrap).
class UserModel {
  UserModel({
    required this.pk,
    required this.role,
    this.displayName = '',
    this.createdAt,
  });

  final String pk;
  final String role; // SELLER | BUYER
  final String displayName;
  final String? createdAt;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      pk: json['pk'] as String,
      role: json['role'] as String,
      displayName: json['displayName'] as String? ?? '',
      createdAt: json['createdAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'pk': pk,
    'role': role,
    'displayName': displayName,
    if (createdAt != null) 'createdAt': createdAt,
  };
}
