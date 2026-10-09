class User {
  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.roles,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    firstName: json['firstName'] as String,
    lastName: json['lastName'] as String,
    email: json['email'] as String,
    roles: List<String>.unmodifiable(json['roles'] as List),
  );

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final List<String> roles;

  String get fullName => '$firstName $lastName';
}
