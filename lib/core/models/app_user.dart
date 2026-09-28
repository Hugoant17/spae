enum UserRole { member, assistant, administrator }

class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });

  final String id;
  final String fullName;
  final String email;
  final UserRole role;

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'] as String,
        fullName: map['full_name'] as String? ?? '',
        email: map['email'] as String? ?? '',
        role: UserRole.values.firstWhere(
          (value) => value.name == map['role'],
          orElse: () => UserRole.member,
        ),
      );
}

