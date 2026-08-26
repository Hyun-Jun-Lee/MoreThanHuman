enum RoleplayDifficulty {
  easy(
    label: 'Easy',
    description: 'Short prompts, clear context, and a gentle pace.',
  ),
  normal(
    label: 'Normal',
    description: 'Natural everyday pacing with useful follow-up questions.',
  ),
  challenge(
    label: 'Challenge',
    description:
        'Unexpected follow-ups that invite longer, more precise answers.',
  );

  const RoleplayDifficulty({required this.label, required this.description});

  final String label;
  final String description;

  String get apiValue {
    return switch (this) {
      RoleplayDifficulty.easy => 'EASY',
      RoleplayDifficulty.normal => 'NORMAL',
      RoleplayDifficulty.challenge => 'CHALLENGE',
    };
  }
}
