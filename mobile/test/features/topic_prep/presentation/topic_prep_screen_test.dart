import 'dart:async';

import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/conversation/conversation.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/topic_prep/topic_prep.dart';
import 'package:curitalk/features/topic_prep/presentation/widgets/tomato_bite_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final custom in [false, true]) {
    testWidgets(
      'refresh only replaces questions and hands them off (custom=$custom)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _FakeTopicPrepRepository();
        final conversations = _FakeConversationRepository();
        await tester.pumpWidget(
          _app(repository: repository, conversationRepository: conversations),
        );
        await tester.pumpAndSettle();
        if (custom) {
          await tester.tap(find.byKey(const ValueKey('custom-focus-open')));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField),
            ),
            'pitching choices',
          );
          await tester.tap(find.text('Create questions'));
          await tester.pumpAndSettle();
        } else {
          await tester.tap(find.text('DEBATE'));
          await tester.pumpAndSettle();
        }
        final refresh = find.byKey(const ValueKey('regenerate-questions'));
        await tester.ensureVisible(refresh);
        final icon = tester.widget<Image>(
          find.descendant(of: refresh, matching: find.byType(Image)),
        );
        expect(
          (icon.image as AssetImage).assetName,
          'assets/images/topic_prep/refresh_directions.png',
        );
        expect(icon.width, 14);
        await tester.tap(refresh);
        await tester.pumpAndSettle();
        expect(
          repository.lastQuestionFocus,
          custom ? 'pitching choices' : contains('DEBATE'),
        );
        expect(repository.lastQuestionSummary, 'Lotte won 8-3.');
        expect(repository.lastPreviousQuestions, hasLength(3));
        expect(repository.topics, ['recent lotte']);
        expect(repository.regenerateCallCount, 0);
        expect(find.text('New question one?'), findsOneWidget);
        expect(find.text('새 질문 하나?'), findsOneWidget);
        await tester.ensureVisible(find.text('DEBATE'));
        if (custom) {
          expect(
            tester
                .widget<AppSelectionChip>(
                  find.byKey(const ValueKey('custom-focus-direction')),
                )
                .selected,
            isTrue,
          );
        } else {
          expect(
            tester
                .widget<AppSelectionChip>(
                  find.ancestor(
                    of: find.text('DEBATE'),
                    matching: find.byType(AppSelectionChip),
                  ),
                )
                .selected,
            isTrue,
          );
        }
        await tester.tap(find.text('CASUAL CHAT'));
        await tester.pumpAndSettle();
        expect(find.text('What stood out in the game?'), findsOneWidget);
        await tester.tap(
          custom
              ? find.byKey(const ValueKey('custom-focus-direction'))
              : find.text('DEBATE'),
        );
        await tester.pumpAndSettle();
        expect(find.text('New question one?'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.bySemanticsLabel('First answer in Korean'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(find.byType(TextField).last, '새 질문에 답해요.');
        await tester.pump();
        await tester.tap(find.byTooltip('Send message'));
        await tester.pumpAndSettle();
        expect(conversations.lastSelectedQuestion, 'New question one?');
        expect(
          conversations.lastCustomFocus,
          custom ? 'pitching choices' : null,
        );
      },
    );
  }

  testWidgets(
    'question refresh blocks duplicate actions and keeps old questions on failure',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _FakeTopicPrepRepository();
      repository.pendingQuestions = Completer<TopicPrepQuestions>();
      await tester.pumpWidget(_app(repository: repository));
      await tester.pumpAndSettle();
      final refresh = find.byKey(const ValueKey('regenerate-questions'));
      await tester.ensureVisible(refresh);
      final cards = find.byKey(const ValueKey('first-question-cards'));
      final cardSize = tester.getSize(cards);
      await tester.tap(refresh);
      await tester.pump();
      expect(tester.widget<IconButton>(refresh).onPressed, isNull);
      expect(
        find.descendant(
          of: refresh,
          matching: find.byType(AppLoadingIndicator),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: refresh, matching: find.byType(Image)),
        findsOneWidget,
      );
      final loader = find.descendant(
        of: cards,
        matching: find.byType(TomatoBiteLoader),
      );
      expect(loader, findsOneWidget);
      expect(tester.getSize(cards), cardSize);
      expect(tester.getCenter(loader), tester.getCenter(cards));
      expect(
        tester
            .widget<Visibility>(
              find
                  .descendant(of: cards, matching: find.byType(Visibility))
                  .first,
            )
            .visible,
        isFalse,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('regenerate-directions')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<ChatComposer>(find.byType(ChatComposer)).enabled,
        isFalse,
      );
      repository.pendingQuestions!.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.byType(TomatoBiteLoader), findsNothing);
      expect(
        tester
            .widget<Visibility>(
              find
                  .descendant(of: cards, matching: find.byType(Visibility))
                  .first,
            )
            .visible,
        isTrue,
      );
      expect(find.text('What stood out in the game?'), findsOneWidget);
      expect(find.text('경기에서 어떤 점이 눈에 띄었나요?'), findsOneWidget);
      expect(
        find.text('We could not prepare new questions. Please try again.'),
        findsOneWidget,
      );
      expect(tester.widget<IconButton>(refresh).onPressed, isNotNull);
      repository.pendingQuestions = null;
      await tester.ensureVisible(refresh);
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(find.text('New question one?'), findsOneWidget);
      expect(
        find.text('We could not prepare new questions. Please try again.'),
        findsNothing,
      );
    },
  );

  testWidgets('tomato loader stays still when animations are disabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: TomatoBiteLoader(semanticLabel: 'Loading'),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));

    final Image tomato = tester.widget<Image>(find.byType(Image));
    expect(
      tomato.image,
      isA<AssetImage>().having(
        (AssetImage image) => image.assetName,
        'assetName',
        'assets/images/loading/tomato_row_0.png',
      ),
    );
  });

  testWidgets('summary appears while directions and questions are loading', (
    WidgetTester tester,
  ) async {
    final _StreamingTopicPrepRepository repository =
        _StreamingTopicPrepRepository();
    await tester.pumpWidget(_app(repository: repository));
    await tester.pump();

    expect(find.text('recent lotte'), findsOneWidget);
    expect(find.byType(TomatoBiteLoader), findsNWidgets(3));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      tester.getCenter(find.byType(TomatoBiteLoader).first).dx,
      closeTo(tester.getCenter(find.byType(AppColorBlockCard).first).dx, 1),
    );
    final Finder summaryCard = find.byType(AppColorBlockCard).first;
    final Finder summaryLabel = find.descendant(
      of: summaryCard,
      matching: find.byType(AppSectionLabel),
    );
    expect(
      tester.getTopLeft(find.byType(TomatoBiteLoader).first).dy -
          tester.getBottomLeft(summaryLabel).dy,
      closeTo(AppSpacing.xs, 1),
    );

    final Image initialTomato = tester.widget<Image>(
      find.descendant(
        of: find.byType(TomatoBiteLoader).first,
        matching: find.byType(Image),
      ),
    );
    expect(
      initialTomato.image,
      isA<AssetImage>().having(
        (AssetImage image) => image.assetName,
        'assetName',
        'assets/images/loading/tomato_row_0.png',
      ),
    );
    await tester.pump(const Duration(milliseconds: 420));
    final Image bittenTomato = tester.widget<Image>(
      find.descendant(
        of: find.byType(TomatoBiteLoader).first,
        matching: find.byType(Image),
      ),
    );
    expect(
      bittenTomato.image,
      isA<AssetImage>().having(
        (AssetImage image) => image.assetName,
        'assetName',
        'assets/images/loading/tomato_row_1.png',
      ),
    );

    repository.events.add(const TopicPrepStreamEvent.summary('Early summary'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Early summary'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Early summary')).dy -
          tester.getBottomLeft(summaryLabel).dy,
      closeTo(AppSpacing.md, 1),
    );
    expect(find.byType(TomatoBiteLoader), findsNWidgets(2));
    expect(find.text('CASUAL CHAT'), findsNothing);

    repository.events.add(
      TopicPrepStreamEvent.card(await repository.prepareTopic('recent lotte')),
    );
    await repository.events.close();
    await tester.pumpAndSettle();
    expect(find.text('Lotte won 8-3.'), findsOneWidget);
    expect(find.text('CASUAL CHAT'), findsOneWidget);
    expect(find.byType(TomatoBiteLoader), findsNothing);
  });

  testWidgets(
    'recommendations hide summary during loading and after preparation',
    (tester) async {
      final repository = _StreamingTopicPrepRepository();
      await tester.pumpWidget(
        _app(
          repository: repository,
          initialLocation:
              '${AppRoute.topicPrep}?topic=recent%20lotte&recommended=true',
        ),
      );
      await tester.pump();
      expect(find.text('SUMMARY'), findsNothing);
      expect(find.byType(TomatoBiteLoader), findsNWidgets(2));
      repository.events.add(
        const TopicPrepStreamEvent.summary('Early summary'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Early summary'), findsNothing);
      repository.events.add(
        TopicPrepStreamEvent.card(
          await repository.prepareTopic('recent lotte'),
        ),
      );
      await repository.events.close();
      await tester.pumpAndSettle();
      expect(find.text('SUMMARY'), findsNothing);
      expect(find.text('Lotte won 8-3.'), findsNothing);
      expect(find.text('CASUAL CHAT'), findsOneWidget);
    },
  );

  for (final locale in ['en', 'ko']) {
    testWidgets(
      'Accent matches direction heading style and spacing in $locale',
      (tester) async {
        await tester.pumpWidget(
          _app(
            repository: _FakeTopicPrepRepository(
              language: LearningLanguageContext.defaultContext,
            ),
            locale: Locale(locale),
            initialLocation:
                '${AppRoute.topicPrep}?topic=recent%20lotte&recommended=true',
          ),
        );
        await tester.pumpAndSettle();
        final accent = find.text('Accent');
        final direction = find.text(
          locale == 'ko'
              ? '어떤 주제가 좋으세요?'
              : 'WHAT WOULD YOU LIKE TO TALK ABOUT?',
        );
        expect(accent, findsOneWidget);
        expect(
          tester.widget<Text>(accent).style,
          tester.widget<Text>(direction).style,
        );
        final accentHeader = find.byKey(const ValueKey('accent-heading'));
        final directionHeader = find.byKey(
          const ValueKey('topic-directions-heading'),
        );
        expect(
          tester.getSize(accentHeader).height,
          tester.getSize(directionHeader).height,
        );
        expect(
          tester.getTopLeft(accent).dy - tester.getTopLeft(accentHeader).dy,
          closeTo(
            tester.getTopLeft(direction).dy -
                tester.getTopLeft(directionHeader).dy,
            0.1,
          ),
        );
        expect(
          tester.getTopLeft(accentHeader).dy -
              tester.getBottomLeft(find.text('recent lotte')).dy,
          AppSpacing.xl,
        );
        expect(
          tester.getTopLeft(directionHeader).dy -
              tester
                  .getBottomLeft(find.byKey(const ValueKey('accent-options')))
                  .dy,
          AppSpacing.xl,
        );
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('accent-options'))).dy -
              tester.getBottomLeft(accentHeader).dy,
          AppSpacing.xs,
        );
        expect(
          tester
                  .getTopLeft(
                    find.byKey(const ValueKey('topic-directions-options')),
                  )
                  .dy -
              tester.getBottomLeft(directionHeader).dy,
          AppSpacing.xs,
        );
      },
    );
  }

  testWidgets(
    'ready state shows summary and default question without sources',
    (WidgetTester tester) async {
      await tester.pumpWidget(_app(repository: _FakeTopicPrepRepository()));
      await tester.pumpAndSettle();

      expect(find.text('Lotte won 8-3.'), findsOneWidget);
      expect(find.text('example.com'), findsNothing);
      expect(find.text('CASUAL CHAT'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('What stood out in the game?'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('What stood out in the game?'), findsOneWidget);
      final Text translation = tester.widget<Text>(
        find.text('경기에서 어떤 점이 눈에 띄었나요?'),
      );
      expect(translation.style?.fontSize, AppTypography.caption.fontSize);
      expect(
        translation.style?.color,
        AppTheme.light.colorScheme.onSurfaceVariant,
      );
      expect(find.bySemanticsLabel('Source: Lotte recap'), findsNothing);
    },
  );

  testWidgets('changing direction swaps first question options', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(repository: _FakeTopicPrepRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DEBATE'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Was the result convincing?'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Was the result convincing?'), findsOneWidget);
    expect(find.text('결과에 설득력이 있었나요?'), findsOneWidget);
    expect(find.text('What stood out in the game?'), findsNothing);
  });

  testWidgets('custom focus generates three first-question options', (
    WidgetTester tester,
  ) async {
    final _FakeTopicPrepRepository repository = _FakeTopicPrepRepository();
    final _FakeConversationRepository conversationRepository =
        _FakeConversationRepository();
    await tester.pumpWidget(
      _app(
        repository: repository,
        conversationRepository: conversationRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('WRITE YOUR OWN'), findsOneWidget);
    expect(find.text('Create questions'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('custom-focus-open')));
    await tester.pumpAndSettle();

    final Finder dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(find.text('What would you like to discuss?'), findsOneWidget);
    final TextField dialogField = tester.widget<TextField>(
      find.descendant(of: dialog, matching: find.byType(TextField)),
    );
    expect(
      dialogField.decoration?.hintText,
      "Enter what you'd like to discuss",
    );
    expect(dialogField.maxLines, 1);
    await tester.tap(find.text('Create questions'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a conversation focus.'), findsOneWidget);
    expect(repository.lastCustomFocus, isNull);

    final Finder customFocusField = find.descendant(
      of: dialog,
      matching: find.byType(TextField),
    );
    await tester.enterText(customFocusField, 'the bullpen performance');
    await tester.tap(find.text('Create questions'));
    await tester.pumpAndSettle();

    expect(dialog, findsNothing);
    expect(repository.lastCustomFocus, 'the bullpen performance');
    final Finder customDirection = find.byKey(
      const ValueKey('custom-focus-direction'),
    );
    expect(customDirection, findsOneWidget);
    expect(find.text('the bullpen performance'), findsOneWidget);
    expect(tester.widget<AppSelectionChip>(customDirection).selected, isTrue);
    await tester.tap(find.text('DEBATE'));
    await tester.pumpAndSettle();
    expect(tester.widget<AppSelectionChip>(customDirection).selected, isFalse);
    await tester.scrollUntilVisible(
      find.text('Was the result convincing?'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Was the result convincing?'), findsOneWidget);

    await tester.scrollUntilVisible(
      customDirection,
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(customDirection);
    await tester.pumpAndSettle();
    expect(tester.widget<AppSelectionChip>(customDirection).selected, isTrue);
    await tester.scrollUntilVisible(
      find.text('How did the bullpen affect the game?'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('How did the bullpen affect the game?'), findsOneWidget);
    expect(find.text('불펜이 경기에 어떤 영향을 주었나요?'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.bySemanticsLabel('First answer in Korean'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField).last, '불펜이 인상적이었어요.');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(conversationRepository.lastCustomFocus, 'the bullpen performance');
    expect(
      conversationRepository.lastSelectedQuestion,
      'How did the bullpen affect the game?',
    );
  });

  testWidgets('canceling custom focus does not generate questions', (
    WidgetTester tester,
  ) async {
    final _FakeTopicPrepRepository repository = _FakeTopicPrepRepository();
    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('custom-focus-open')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'a discarded idea',
    );
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.lastCustomFocus, isNull);
    await tester.tap(find.byKey(const ValueKey('custom-focus-open')));
    await tester.pumpAndSettle();
    final TextField reopenedField = tester.widget<TextField>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
    );
    expect(reopenedField.controller?.text, isEmpty);
  });

  testWidgets('direction actions fit a narrow screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(repository: _FakeTopicPrepRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('regenerate-directions')), findsOneWidget);
    expect(find.byKey(const ValueKey('custom-focus-open')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('custom-focus-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('custom-focus-open')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'the bullpen performance after the seventh inning',
    );
    await tester.tap(find.text('Create questions'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('custom-focus-direction')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('custom-focus-direction')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'regenerating directions keeps the topic card and replaces options',
    (WidgetTester tester) async {
      final _FakeTopicPrepRepository repository = _FakeTopicPrepRepository();
      await tester.pumpWidget(_app(repository: repository));
      await tester.pumpAndSettle();

      final Finder refreshButton = find.byKey(
        const ValueKey('regenerate-directions'),
      );
      final Rect heading = tester.getRect(
        find.text('WHAT WOULD YOU LIKE TO TALK ABOUT?'),
      );
      final Rect refresh = tester.getRect(refreshButton);
      expect(refresh.left, greaterThanOrEqualTo(heading.right));
      expect(refresh.left - heading.right, lessThanOrEqualTo(8));
      expect((refresh.center.dy - heading.center.dy).abs(), lessThan(2));
      final Image refreshIcon = tester.widget<Image>(
        find.descendant(of: refreshButton, matching: find.byType(Image)),
      );
      expect(
        (refreshIcon.image as AssetImage).assetName,
        'assets/images/topic_prep/refresh_directions.png',
      );
      expect(refreshIcon.width, 14);
      expect(refreshIcon.height, 14);
      final ButtonStyle? refreshStyle = tester
          .widget<IconButton>(refreshButton)
          .style;
      expect(
        refreshStyle?.backgroundColor?.resolve(<WidgetState>{}),
        Colors.transparent,
      );
      expect(
        refreshStyle?.backgroundColor?.resolve(<WidgetState>{
          WidgetState.disabled,
        }),
        Colors.transparent,
      );
      expect(find.text('🔄'), findsNothing);
      expect(find.text('Show different directions'), findsNothing);
      expect(find.byTooltip('Refresh directions'), findsOneWidget);
      final Rect customFocusButton = tester.getRect(
        find.byKey(const ValueKey('custom-focus-open')),
      );
      expect(customFocusButton.top, greaterThanOrEqualTo(refresh.bottom));
      expect(
        tester
            .widget<AppSelectionChip>(
              find.byKey(const ValueKey('custom-focus-open')),
            )
            .label,
        'Write your own',
      );

      await tester.tap(refreshButton);
      await tester.pumpAndSettle();

      expect(repository.regenerateCallCount, 1);
      expect(find.text('FRESH CONVERSATION'), findsOneWidget);
      expect(find.text('Lotte won 8-3.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('결정적 순간은 무엇이었나요?'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('결정적 순간은 무엇이었나요?'), findsOneWidget);
    },
  );

  testWidgets('low-quality state can retry with an example topic', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        initialLocation:
            '${AppRoute.topicPrep}?topic=${Uri.encodeQueryComponent('too broad')}',
        repository: _FakeTopicPrepRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Try a more specific topic.'), findsOneWidget);

    await tester.tap(find.text('최근 롯데 자이언츠 경기'));
    await tester.pumpAndSettle();

    expect(find.text('Lotte won 8-3.'), findsOneWidget);
  });

  testWidgets('error state can retry the same topic', (
    WidgetTester tester,
  ) async {
    final _FakeTopicPrepRepository repository = _FakeTopicPrepRepository(
      failFirstTopic: 'flaky topic',
    );
    await tester.pumpWidget(
      _app(
        initialLocation:
            '${AppRoute.topicPrep}?topic=${Uri.encodeQueryComponent('flaky topic')}',
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not prepare this topic.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Lotte won 8-3.'), findsOneWidget);
    expect(repository.topics, <String>['flaky topic', 'flaky topic']);
  });

  testWidgets('first answer starts free-chat conversation', (
    WidgetTester tester,
  ) async {
    final _FakeConversationRepository conversationRepository =
        _FakeConversationRepository();
    await tester.pumpWidget(
      _app(
        repository: _FakeTopicPrepRepository(),
        conversationRepository: conversationRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.bySemanticsLabel('First answer in Korean'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField).last, '오늘 불펜이 좋았어요.');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(find.text('Conversation conversation-id'), findsOneWidget);
    expect(conversationRepository.lastFirstMessage, '오늘 불펜이 좋았어요.');
    expect(conversationRepository.lastDirection, 'CASUAL_CHAT');
    expect(
      conversationRepository.lastSelectedQuestion,
      'What stood out in the game?',
    );
  });

  testWidgets('voice first answer starts free-chat conversation', (
    WidgetTester tester,
  ) async {
    final _FakeConversationRepository conversationRepository =
        _FakeConversationRepository();
    final _FakeConversationAudioRecorder recorder =
        _FakeConversationAudioRecorder();
    await tester.pumpWidget(
      _app(
        repository: _FakeTopicPrepRepository(),
        conversationRepository: conversationRepository,
        recorder: recorder,
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byTooltip('Voice input'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byTooltip('Voice input'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Stop recording'));
    await tester.pumpAndSettle();
    await tester.pump(minimumVoiceRecordingDuration);
    await tester.tap(find.byTooltip('Stop recording'));
    await tester.pumpAndSettle();

    expect(find.text('Conversation conversation-id'), findsOneWidget);
    expect(recorder.startCount, 1);
    expect(recorder.stopCount, 1);
    expect(conversationRepository.lastAudioFilename, 'answer.m4a');
    expect(conversationRepository.lastDirection, 'CASUAL_CHAT');
    expect(
      conversationRepository.lastSelectedQuestion,
      'What stood out in the game?',
    );
  });
}

Widget _app({
  required TopicPrepRepository repository,
  ConversationRepository? conversationRepository,
  ConversationAudioRecorder? recorder,
  Locale? locale,
  String initialLocation = '${AppRoute.topicPrep}?topic=recent%20lotte',
}) {
  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(path: AppRoute.home, builder: (_, _) => const Text("Home")),
      GoRoute(
        path: AppRoute.topicInput,
        builder: (_, GoRouterState state) {
          return TopicInputScreen(
            initialTopic: state.uri.queryParameters['topic'],
          );
        },
      ),
      GoRoute(
        path: AppRoute.topicPrep,
        builder: (_, GoRouterState state) {
          return TopicPrepScreen(
            initialTopic: state.uri.queryParameters['topic']!,
            isRecommendedTopic:
                state.uri.queryParameters['recommended'] == 'true',
          );
        },
      ),
      GoRoute(
        path: '${AppRoute.conversation}/:conversationId',
        builder: (_, GoRouterState state) {
          return Text('Conversation ${state.pathParameters['conversationId']}');
        },
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      topicPrepRepositoryProvider.overrideWithValue(repository),
      if (conversationRepository != null)
        conversationRepositoryProvider.overrideWithValue(
          conversationRepository,
        ),
      if (recorder != null)
        conversationAudioRecorderProvider.overrideWithValue(recorder),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    ),
  );
}

class _FakeTopicPrepRepository
    implements
        TopicPrepRepository,
        TopicPrepCustomFocusRepository,
        TopicPrepQuestionsRepository {
  _FakeTopicPrepRepository({
    this.failFirstTopic,
    this.language = _koreanPracticeLanguage,
  });

  final LearningLanguageContext language;

  final String? failFirstTopic;
  final List<String> topics = <String>[];
  String? lastCustomFocus;
  int regenerateCallCount = 0;
  String? lastQuestionFocus;
  String? lastQuestionSummary;
  List<String>? lastPreviousQuestions;
  Completer<TopicPrepQuestions>? pendingQuestions;

  @override
  Future<TopicPrepQuestions> regenerateQuestions({
    required String topic,
    required String focus,
    required String summary,
    required List<String> previousQuestions,
  }) async {
    lastQuestionFocus = focus;
    lastQuestionSummary = summary;
    lastPreviousQuestions = previousQuestions;
    if (pendingQuestions != null) return pendingQuestions!.future;
    return const TopicPrepQuestions(
      firstQuestions: [
        'New question one?',
        'New question two?',
        'New question three?',
      ],
      firstQuestionTranslations: ['새 질문 하나?', '새 질문 둘?', '새 질문 셋?'],
    );
  }

  @override
  Future<TopicPrepResult> prepareTopic(String topic) async {
    topics.add(topic);
    if (topic == failFirstTopic &&
        topics.where((value) => value == topic).length == 1) {
      throw StateError('Temporary failure');
    }
    if (topic == 'too broad') {
      return TopicPrepResult(
        ready: false,
        card: null,
        quality: _quality(isSufficient: false),
        language: language,
        retryGuidance: 'Try a more specific topic.',
        exampleTopics: const <String>['최근 롯데 자이언츠 경기'],
      );
    }
    return TopicPrepResult(
      ready: true,
      card: TopicPrepCard(
        topic: topic,
        summary: 'Lotte won 8-3.',
        directions: <TopicPrepDirection>[
          _direction(
            TopicPrepDirectionType.casualChat,
            'Casual Chat',
            <String>[
              'What stood out in the game?',
              'Which player caught your eye?',
              'How would you explain the result?',
            ],
            translations: const <String>[
              '경기에서 어떤 점이 눈에 띄었나요?',
              '어떤 선수가 눈에 들어왔나요?',
              '결과를 어떻게 설명하겠어요?',
            ],
          ),
          _direction(
            TopicPrepDirectionType.debate,
            'Debate',
            <String>[
              'Was the result convincing?',
              'Which side has the stronger argument?',
              'What would critics say?',
            ],
            translations: const <String>[
              '결과에 설득력이 있었나요?',
              '어느 쪽 주장이 더 강한가요?',
              '비평가들은 뭐라고 할까요?',
            ],
          ),
          _direction(
            TopicPrepDirectionType.explanationPractice,
            'Explain',
            <String>[
              'How would you explain this to a friend?',
              'What background matters most?',
              'What happened first?',
            ],
          ),
        ],
        sources: const <SearchSource>[
          SearchSource(
            title: 'Lotte recap',
            url: 'https://example.com/sports/lotte',
            snippet: 'Lotte beat KIA.',
          ),
        ],
        quality: _quality(),
        timestamp: DateTime.utc(2026, 7, 2),
      ),
      quality: _quality(),
      language: language,
      exampleTopics: const <String>[],
    );
  }

  @override
  Future<CustomFocusQuestions> prepareCustomFocusQuestions({
    required String topic,
    required String customFocus,
  }) async {
    lastCustomFocus = customFocus;
    return CustomFocusQuestions(
      ready: true,
      customFocus: customFocus,
      firstQuestions: const <String>[
        'How did the bullpen affect the game?',
        'Which reliever mattered most?',
        'What would you say about the bullpen?',
      ],
      firstQuestionTranslations: const <String>[
        '불펜이 경기에 어떤 영향을 주었나요?',
        '어떤 구원 투수가 가장 중요했나요?',
        '불펜에 대해 어떻게 말하겠어요?',
      ],
    );
  }

  @override
  Future<TopicPrepDirections> regenerateDirections({
    required String topic,
    required List<String> previousDirections,
  }) async {
    regenerateCallCount += 1;
    return TopicPrepDirections(<TopicPrepDirection>[
      _direction(
        TopicPrepDirectionType.casualChat,
        'Fresh conversation',
        <String>[
          'What was the key moment?',
          'Who impressed you?',
          'How would you describe it?',
        ],
        translations: const <String>[
          '결정적 순간은 무엇이었나요?',
          '누가 인상적이었나요?',
          '어떻게 묘사하겠어요?',
        ],
      ),
      _direction(TopicPrepDirectionType.debate, 'Different opinion', <String>[
        'Do you agree with the result?',
        'What is the strongest reason?',
        'What would the other side say?',
      ]),
      _direction(
        TopicPrepDirectionType.explanationPractice,
        'New explanation',
        <String>[
          'How would you explain the result?',
          'What background matters?',
          'What happened first?',
        ],
      ),
    ]);
  }
}

class _StreamingTopicPrepRepository extends _FakeTopicPrepRepository
    implements TopicPrepStreamRepository {
  final StreamController<TopicPrepStreamEvent> events =
      StreamController<TopicPrepStreamEvent>();

  @override
  Stream<TopicPrepStreamEvent> prepareTopicStream(String topic) =>
      events.stream;
}

const LearningLanguageContext _koreanPracticeLanguage = LearningLanguageContext(
  nativeLanguage: LearningLanguageCode.en,
  targetLanguage: LearningLanguageCode.ko,
  feedbackLanguage: LearningLanguageCode.en,
);

TopicPrepDirection _direction(
  TopicPrepDirectionType type,
  String title,
  List<String> questions, {
  List<String> translations = const <String>[],
}) {
  return TopicPrepDirection(
    direction: type,
    title: title,
    description: '$title practice',
    firstQuestions: questions,
    firstQuestionTranslations: translations,
  );
}

class _FakeConversationRepository
    implements ConversationRepository, CustomFocusConversationRepository {
  String? lastFirstMessage;
  String? lastDirection;
  String? lastSelectedQuestion;
  String? lastAudioFilename;
  String? lastCustomFocus;

  @override
  Future<MultimodalConversationResponse> startFreeChat({
    String ttsAccent = 'us',
    required String firstMessage,
    String? searchContext,
    String? topic,
    String? conversationDirection,
    String? selectedQuestion,
    bool includeAudioResponse = true,
  }) async {
    lastFirstMessage = firstMessage;
    lastDirection = conversationDirection;
    lastSelectedQuestion = selectedQuestion;
    return const MultimodalConversationResponse(
      conversationId: 'conversation-id',
      messageId: 'message-id',
      conversationType: ConversationType.freeChat,
      response: 'Great. Tell me more.',
      inputMode: ConversationInputMode.text,
    );
  }

  @override
  Future<MultimodalConversationResponse> startFreeChatWithAudio({
    String ttsAccent = 'us',
    required ConversationAudioFile audioFile,
    String? searchContext,
    String? topic,
    String? conversationDirection,
    String? selectedQuestion,
    bool includeAudioResponse = true,
  }) async {
    lastAudioFilename = audioFile.filename;
    lastDirection = conversationDirection;
    lastSelectedQuestion = selectedQuestion;
    return const MultimodalConversationResponse(
      conversationId: 'conversation-id',
      messageId: 'message-id',
      conversationType: ConversationType.freeChat,
      response: 'Great. Tell me more.',
      inputMode: ConversationInputMode.audio,
      transcript: '오늘 불펜이 좋았어요.',
    );
  }

  @override
  Future<MultimodalConversationResponse> startFreeChatWithCustomFocus({
    String ttsAccent = 'us',
    required String firstMessage,
    String? searchContext,
    String? topic,
    String? selectedQuestion,
    required String customFocus,
    bool includeAudioResponse = true,
  }) async {
    lastFirstMessage = firstMessage;
    lastSelectedQuestion = selectedQuestion;
    lastCustomFocus = customFocus;
    return const MultimodalConversationResponse(
      conversationId: 'conversation-id',
      messageId: 'message-id',
      conversationType: ConversationType.freeChat,
      response: 'Great. Tell me more.',
      inputMode: ConversationInputMode.text,
    );
  }

  @override
  Future<MultimodalConversationResponse> startFreeChatWithAudioAndCustomFocus({
    String ttsAccent = 'us',
    required ConversationAudioFile audioFile,
    String? searchContext,
    String? topic,
    String? selectedQuestion,
    required String customFocus,
    bool includeAudioResponse = true,
  }) async {
    lastAudioFilename = audioFile.filename;
    lastSelectedQuestion = selectedQuestion;
    lastCustomFocus = customFocus;
    return const MultimodalConversationResponse(
      conversationId: 'conversation-id',
      messageId: 'message-id',
      conversationType: ConversationType.freeChat,
      response: 'Great. Tell me more.',
      inputMode: ConversationInputMode.audio,
    );
  }

  @override
  Future<MultimodalConversationResponse> startRoleplay({
    String ttsAccent = 'us',
    required String roleCharacter,
    String? searchContext,
    bool includeAudioResponse = true,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PaginatedMessages> listMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<MessageResponse> sendMessage({
    required String conversationId,
    required String message,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<MultimodalMessageResponse> sendTextTurn({
    required String conversationId,
    required String text,
    bool includeAudioResponse = true,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<MultimodalMessageResponse> sendAudioTurn({
    required String conversationId,
    required ConversationAudioFile audioFile,
    bool includeAudioResponse = true,
  }) {
    throw UnimplementedError();
  }
}

class _FakeConversationAudioRecorder implements ConversationAudioRecorder {
  int startCount = 0;
  int stopCount = 0;
  int cancelCount = 0;

  @override
  Future<void> start() async {
    startCount++;
  }

  @override
  Future<ConversationAudioFile> stop() async {
    stopCount++;
    return const ConversationAudioFile(
      bytes: <int>[1, 2, 3],
      filename: 'answer.m4a',
      contentType: 'audio/m4a',
    );
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  @override
  Future<void> dispose() async {}
}

TopicPrepQuality _quality({bool isSufficient = true}) {
  return TopicPrepQuality(
    isSufficient: isSufficient,
    sourceCount: isSufficient ? 3 : 1,
    hasEnoughSources: isSufficient,
    relevance: isSufficient,
    freshness: isSufficient,
    specificity: isSufficient,
  );
}
