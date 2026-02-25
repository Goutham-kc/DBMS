class UserModel {
  final String id;
  final String email;
  final String? gymId;

  /// Used ONLY for routing (owner/trainer/member/none)
  final String appRole;

  /// Used for gym identity (owner/trainer/member)
  final String? membershipRole;

  final bool isOwner;
  final String? trainerId;

  UserModel({
    required this.id,
    required this.email,
    this.gymId,
    required this.appRole,
    this.membershipRole,
    required this.isOwner,
    this.trainerId,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      gymId: map['gym_id'],
      appRole: map['app_role'] ?? 'none',
      membershipRole: map['membership_role'],
      isOwner: map['is_owner'] ?? false,
      trainerId: map['trainer_id'],
    );
  }
}