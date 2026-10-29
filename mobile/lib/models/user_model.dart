class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final int balance;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.balance,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'estudiante',
      balance: json['balance'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'balance': balance,
    };
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? role,
    int? balance,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      balance: balance ?? this.balance,
    );
  }
}
