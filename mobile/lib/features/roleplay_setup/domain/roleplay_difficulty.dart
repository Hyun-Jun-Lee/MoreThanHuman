enum RoleplayDifficulty {
  easy(
    label: 'Easy',
    description: 'Short, simple questions with a slower pace.',
    promptInstruction: 'uses short, simple questions and keeps the pace gentle',
  ),
  normal(
    label: 'Normal',
    description: 'Natural everyday conversation.',
    promptInstruction: 'keeps the conversation natural and everyday',
  ),
  challenge(
    label: 'Challenge',
    description: 'Unexpected questions that invite longer answers.',
    promptInstruction:
        'asks unexpected follow-up questions and encourages longer answers',
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
