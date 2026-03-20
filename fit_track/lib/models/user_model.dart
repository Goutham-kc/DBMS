/// UserModel — typed wrapper around a row from the [profiles] table.
///
/// profiles schema:
///   id, email, gym_id, trainer_id,
///   membership_role, app_role, role, is_owner
///
/// NOTE: app_role, membership_role, and role always hold the same
/// value (owner / trainer / member / none). They are written together
/// by SupabaseService. [role] is the single field exposed here;
/// the redundant columns exist only for legacy reasons and can be
/// collapsed into one in a future DB migration.
class UserModel {
  final String id;
  final String email;
  final String? gymId;
  final String? trainerId;

  /// The user's role: 'owner' | 'trainer' | 'member' | 'none'
  final String role;

  /// Convenience getters — no need to compare strings everywhere.
  bool get isOwner   => role == 'owner';
  bool get isTrainer => role == 'trainer';
  bool get isMember  => role == 'member';
  bool get hasRole   => role != 'none';
  bool get hasGym    => gymId != null;
  bool get hasTrainer => trainerId != null;

  const UserModel({
    required this.id,
    required this.email,
    required this.role,
    this.gymId,
    this.trainerId,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id:        map['id']        as String? ?? '',
      email:     map['email']     as String? ?? '',
      gymId:     map['gym_id']    as String?,
      trainerId: map['trainer_id'] as String?,
      // app_role is the authoritative routing field
      role:      map['app_role']  as String? ?? 'none',
    );
  }

  /// Creates a copy with specific fields overridden.
  UserModel copyWith({
    String? email,
    String? gymId,
    String? trainerId,
    String? role,
  }) {
    return UserModel(
      id:        id,
      email:     email      ?? this.email,
      gymId:     gymId      ?? this.gymId,
      trainerId: trainerId  ?? this.trainerId,
      role:      role       ?? this.role,
    );
  }

  @override
  String toString() =>
      'UserModel(id: $id, email: $email, role: $role, gymId: $gymId)';
}