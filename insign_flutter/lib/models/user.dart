// lib/models/user.dart

class User {
  final int id;
  final String email;
  final String? displayName;
  final String? lastLoginAt;
  final String? provider;
  final String? avatarUrl;

  const User({
    required this.id,
    required this.email,
    this.displayName,
    this.lastLoginAt,
    this.provider,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      lastLoginAt: json['lastLoginAt'] as String?,
      provider: json['provider'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'lastLoginAt': lastLoginAt,
      'provider': provider,
      'avatarUrl': avatarUrl,
    };
  }
}

class AuthResponse {
  final User user;
  final String accessToken;
  final int expiresIn;

  const AuthResponse({
    required this.user,
    required this.accessToken,
    required this.expiresIn,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['accessToken'] as String,
      expiresIn: json['expiresIn'] as int,
    );
  }
}
