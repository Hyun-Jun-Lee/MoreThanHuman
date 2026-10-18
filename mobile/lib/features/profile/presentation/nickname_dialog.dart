import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:randino/randino.dart';

Future<void> showNicknameDialog(
  BuildContext context, {
  required bool requiredSetup,
  String? initialNickname,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !requiredSetup,
    builder: (_) => NicknameDialog(
      requiredSetup: requiredSetup,
      initialNickname: initialNickname,
    ),
  );
}

class NicknameDialog extends ConsumerStatefulWidget {
  const NicknameDialog({
    required this.requiredSetup,
    this.initialNickname,
    super.key,
  });

  final bool requiredSetup;
  final String? initialNickname;

  @override
  ConsumerState<NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends ConsumerState<NicknameDialog> {
  late final TextEditingController _controller;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final String initialNickname;
    if (widget.requiredSetup && widget.initialNickname == null) {
      final locales = WidgetsBinding.instance.platformDispatcher.locales;
      final language = locales.isNotEmpty && locales.first.languageCode == 'ko'
          ? WordLanguage.en
          : WordLanguage.ko;
      initialNickname = randNickname(
        language: language,
        vocabulary: RandVocabulary.basic,
        maxLength: 20,
      ).single;
    } else {
      initialNickname = widget.initialNickname ?? '';
    }
    _controller = TextEditingController(text: initialNickname);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final copy = AppCopy.of(context);
    final nickname = _controller.text.trim();
    if (nickname.isEmpty ||
        nickname.runes.length > 20 ||
        nickname.runes.any((code) => code < 32 || code == 127)) {
      setState(() => _error = copy.nicknameInvalid);
      return;
    }
    setState(() {
      _error = null;
      _isSaving = true;
    });
    try {
      await ref.read(authControllerProvider.notifier).updateNickname(nickname);
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) setState(() => _error = copy.nicknameSaveFailed);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    return PopScope(
      canPop: !widget.requiredSetup && !_isSaving,
      child: AlertDialog(
        title: Text(
          widget.requiredSetup
              ? copy.nicknameSetupTitle
              : copy.nicknameEditTitle,
        ),
        content: TextField(
          key: const ValueKey('nickname-input'),
          controller: _controller,
          autofocus: true,
          enabled: !_isSaving,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.none,
          decoration: InputDecoration(
            labelText: copy.nicknameHint,
            errorText: _error,
          ),
          onSubmitted: (_) => _save(),
        ),
        actions: <Widget>[
          if (!widget.requiredSetup)
            TextButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              child: Text(copy.cancelLabel),
            ),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(copy.nicknameSaveLabel),
          ),
        ],
      ),
    );
  }
}
