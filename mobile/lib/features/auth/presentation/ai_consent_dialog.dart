import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/features/auth/application/ai_consent_controller.dart';
import 'package:curitalk/features/auth/domain/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

typedef AIConsentGate =
    Future<bool> Function(BuildContext context, WidgetRef ref);
final aiConsentGateProvider = Provider<AIConsentGate>((ref) => ensureAIConsent);

Future<bool> ensureAIConsent(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(aiConsentControllerProvider.notifier);
  final status = await controller.load();
  if (status.accepted) return true;
  if (!context.mounted) return false;
  return await showAIConsentNotice(
        context,
        load: controller.load,
        initialStatus: status,
        onChoice: (notice, acceptAI) async => (await controller.recordChoice(
          notice,
          acceptAI: acceptAI,
        )).accepted,
      ) ??
      false;
}

/// 계정 생성 전에도 같은 안내를 보여주고, 저장 실패에는 선택 화면을 유지해요.
Future<bool?> showAIConsentNotice(
  BuildContext context, {
  required Future<AIConsentStatus> Function() load,
  required Future<bool> Function(AIConsentStatus, bool) onChoice,
  AIConsentStatus? initialStatus,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _AIConsentNotice(
    load: load,
    onChoice: onChoice,
    initialStatus: initialStatus,
  ),
);

class _AIConsentNotice extends StatefulWidget {
  const _AIConsentNotice({
    required this.load,
    required this.onChoice,
    this.initialStatus,
  });
  final Future<AIConsentStatus> Function() load;
  final Future<bool> Function(AIConsentStatus, bool) onChoice;
  final AIConsentStatus? initialStatus;
  @override
  State<_AIConsentNotice> createState() => _AIConsentNoticeState();
}

class _AIConsentNoticeState extends State<_AIConsentNotice> {
  AIConsentStatus? _notice;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _notice = widget.initialStatus;
    if (_notice == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final notice = await widget.load();
      if (mounted) setState(() => _notice = notice);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose(bool acceptAI) async {
    if (_busy || _notice == null) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final accepted = await widget.onChoice(_notice!, acceptAI);
      if (mounted) Navigator.of(context).pop(accepted);
    } catch (_) {
      // 버전 변경을 포함한 실패 후에는 최신 고지를 다시 확인해요.
      if (mounted) {
        setState(() {
          _failed = true;
          _notice = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final notice = _notice;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(
          notice?.accepted == true
              ? copy.privacyPolicyLabel
              : copy.aiConsentTitle,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notice != null && !notice.accepted) ...[
                Text(
                  copy.aiConsentRequiredLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    copy.aiConsentRequiredWarning,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                notice?.accepted == true
                    ? copy.privacyNoticeDescription
                    : copy.aiConsentDescription,
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator(),
                ),
              if (_failed)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(copy.aiConsentSaveFailed),
                ),
            ],
          ),
        ),
        actions: [
          if (notice != null)
            TextButton(
              onPressed: () async {
                final url = notice.privacyPolicyUrlFor(isKorean: copy.isKorean);
                try {
                  if (!await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  )) {
                    if (mounted) setState(() => _failed = true);
                  }
                } catch (_) {
                  if (mounted) setState(() => _failed = true);
                }
              },
              child: Text(copy.privacyPolicyLabel),
            ),
          if (_failed && notice == null)
            TextButton(
              onPressed: _busy ? null : _load,
              child: Text(copy.retryLabel),
            ),
          if (notice != null && !notice.accepted)
            TextButton(
              onPressed: _busy ? null : () => _choose(false),
              child: Text(copy.aiConsentLaterLabel),
            ),
          if (notice != null)
            FilledButton(
              onPressed: _busy ? null : () => _choose(!notice.accepted),
              child: Text(
                notice.accepted
                    ? copy.privacyNoticeContinueLabel
                    : copy.agreeAndContinueLabel,
              ),
            ),
        ],
      ),
    );
  }
}
