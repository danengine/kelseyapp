class UserProfile {
  const UserProfile({
    required this.email,
    this.firstName,
    this.middleName,
    this.lastName,
    this.roles = const [],
  });

  final String email;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final List<String> roles;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    List<String> roles;
    if (rawRoles is List) {
      roles = rawRoles.map((r) => r.toString()).where((r) => r.isNotEmpty).toList();
    } else {
      roles = const [];
    }

    return UserProfile(
      email: json['email'] as String? ?? '',
      firstName: json['firstName'] as String?,
      middleName: json['middleName'] as String?,
      lastName: json['lastName'] as String?,
      roles: roles,
    );
  }

  String get fullName {
    final parts = [firstName, middleName, lastName]
        .where((part) => part != null && part.trim().isNotEmpty)
        .map((part) => part!.trim());
    final name = parts.join(' ');
    return name.isNotEmpty ? name : email;
  }

  String get roleLabel {
    if (roles.isEmpty) return 'Guest';
    return roles.join(', ');
  }

  bool get isAdmin => roles.any((role) => role.toLowerCase() == 'admin');

  bool get isAgent => roles.any((role) => role.toLowerCase() == 'agent');

  bool get canAccessRewards => isAgent || isAdmin;

  String get avatarInitial {
    final trimmedFirst = firstName?.trim();
    if (trimmedFirst != null && trimmedFirst.isNotEmpty) {
      return trimmedFirst[0].toUpperCase();
    }
    if (email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }

  Map<String, dynamic> toJson() => {
        'email': email,
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'roles': roles,
      };
}
