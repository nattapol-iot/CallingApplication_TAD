class EmployeeProfile {
  final String userId;
  final String username;
  final String displayName;
  final String positionCode;
  final String positionName;

  const EmployeeProfile({
    this.userId = '',
    this.username = '',
    required this.displayName,
    required this.positionCode,
    this.positionName = '',
  });
}

class UserAccount {
  final String userId;
  final String username;
  final String displayName;
  final String positionCode;
  final String positionName;
  final String passwordHash;

  const UserAccount({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.positionCode,
    this.positionName = '',
    required this.passwordHash,
  });

  factory UserAccount.fromJson(Map<String, dynamic> j) {
    final nick = (j['nick_name']?.toString() ?? '').trim();
    final first = (j['first_name']?.toString() ?? '').trim();
    final last = (j['last_name']?.toString() ?? '').trim();
    final name = nick.isNotEmpty
        ? nick
        : ([first, last].where((x) => x.isNotEmpty).join(' ')).trim();

    return UserAccount(
      userId: j['user_id']?.toString() ?? '',
      username: j['username']?.toString() ?? '',
      displayName: name.isNotEmpty ? name : (j['username']?.toString() ?? ''),
      positionCode: j['position_code']?.toString() ?? '',
      positionName: j['position_name']?.toString() ?? '',
      passwordHash: j['password']?.toString() ?? '',
    );
  }
}
