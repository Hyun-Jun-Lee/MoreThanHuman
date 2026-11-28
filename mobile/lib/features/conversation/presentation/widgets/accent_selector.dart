import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:flutter/material.dart';
import 'package:curitalk/core/copy/app_copy.dart';

/// 대화 생성 화면에서 사용하는 영어 억양 선택이에요.
class AccentSelector extends StatelessWidget {
  const AccentSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.sectionHeading = false,
  });
  final bool sectionHeading;
  final String value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    const options = {
      'us': 'United States',
      'gb': 'United Kingdom',
      'au': 'Australia',
    };
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        top: sectionHeading ? AppSpacing.xl : AppSpacing.md,
        bottom: sectionHeading ? 0 : AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            key: const ValueKey('accent-heading'),
            constraints: BoxConstraints(minHeight: sectionHeading ? 48 : 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppCopy.of(context).englishAccentLabel,
                style: sectionHeading
                    ? AppTypography.label.copyWith(color: colors.onSurface)
                    : Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            key: const ValueKey('accent-options'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final option in options.entries)
                Expanded(
                  child: Semantics(
                    label: '${option.value} accent',
                    selected: value == option.key,
                    button: true,
                    child: InkWell(
                      onTap: onChanged == null
                          ? null
                          : () => onChanged!(option.key),
                      borderRadius: BorderRadius.circular(12),
                      child: ExcludeSemantics(
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 88),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 4,
                          ),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/flags/${option.key}.png',
                                width: 40,
                                height: 24,
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height:
                                    MediaQuery.textScalerOf(context).scale(11) *
                                    2.6,
                                child: Text(
                                  option.value,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        fontSize: 11,
                                        height: 1.3,
                                        color: colors.onSurface,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: value == option.key
                                    ? Image.asset(
                                        'assets/images/snack_tomato/origin_tomato.png',
                                        key: ValueKey(
                                          'accent-selected-${option.key}',
                                        ),
                                        cacheWidth: 72,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
