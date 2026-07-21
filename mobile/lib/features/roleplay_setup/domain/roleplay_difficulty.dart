enum RoleplayDifficulty {
  easy(
    label: 'Easy',
    description: 'Short prompts, clear context, and a gentle pace.',
    promptInstruction: 'uses short prompts, clear context, and a gentle pace',
  ),
  normal(
    label: 'Normal',
    description: 'Natural everyday pacing with useful follow-up questions.',
    promptInstruction:
        'keeps everyday pacing and asks useful follow-up questions',
  ),
  challenge(
    label: 'Challenge',
    description:
        'Unexpected follow-ups that invite longer, more precise answers.',
    promptInstruction:
        'asks unexpected follow-up questions and encourages longer, more precise answers',
  );

  const RoleplayDifficulty({
    required this.label,
    required this.description,
    required this.promptInstruction,
  });

  final String label;
  final String description;
  final String promptInstruction;
}
