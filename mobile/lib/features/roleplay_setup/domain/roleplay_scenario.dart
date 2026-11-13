import 'package:curitalk/features/language/language.dart';
import 'package:flutter/material.dart';

class RoleplayScenario {
  const RoleplayScenario({
    required this.id,
    required this.title,
    required this.description,
    required this.descriptionKo,
    required this.roleCharacter,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final String descriptionKo;
  final String roleCharacter;
  final IconData icon;

  String descriptionFor(LearningLanguageCode nativeLanguage) =>
      nativeLanguage == LearningLanguageCode.ko ? descriptionKo : description;
}

const List<RoleplayScenario> enRoleplayScenarios = <RoleplayScenario>[
  RoleplayScenario(
    id: 'cafe_order',
    title: 'Cafe order',
    description: 'Order drinks, ask for options, and pay naturally.',
    descriptionKo: '음료를 주문하고, 메뉴를 물어보고, 자연스럽게 결제해요.',
    roleCharacter: 'a friendly cafe barista taking an order',
    icon: Icons.local_cafe_outlined,
  ),
  RoleplayScenario(
    id: 'hotel_check_in',
    title: 'Hotel check-in',
    description: 'Confirm a booking and ask about hotel details.',
    descriptionKo: '예약을 확인하고 호텔 이용 정보를 물어봐요.',
    roleCharacter: 'a hotel front desk staff member helping with check-in',
    icon: Icons.hotel_outlined,
  ),
  RoleplayScenario(
    id: 'airport_immigration',
    title: 'Airport immigration',
    description: 'Answer travel purpose and arrival questions.',
    descriptionKo: '입국 목적과 도착 관련 질문에 답해요.',
    roleCharacter: 'an airport immigration officer asking entry questions',
    icon: Icons.flight_land_outlined,
  ),
  RoleplayScenario(
    id: 'job_interview',
    title: 'Job interview',
    description: 'Practice answers about experience and strengths.',
    descriptionKo: '경험과 강점에 대한 답변을 연습해요.',
    roleCharacter: 'a job interviewer asking practical interview questions',
    icon: Icons.work_outline_rounded,
  ),
  RoleplayScenario(
    id: 'meeting_small_talk',
    title: 'Meeting small talk',
    description: 'Warm up before a meeting with casual work chat.',
    descriptionKo: '회의 전에 가벼운 직장 대화를 나눠요.',
    roleCharacter: 'a coworker making small talk before a meeting',
    icon: Icons.groups_2_outlined,
  ),
  RoleplayScenario(
    id: 'friend_conversation',
    title: 'Friend conversation',
    description: 'Talk casually about your day, plans, and opinions.',
    descriptionKo: '하루 일과와 계획, 생각을 편하게 이야기해요.',
    roleCharacter: 'a close friend having a casual conversation',
    icon: Icons.forum_outlined,
  ),
  RoleplayScenario(
    id: 'meeting_opinion',
    title: 'Meeting opinion',
    description: 'Share an opinion and respond to follow-up questions.',
    descriptionKo: '의견을 말하고 이어지는 질문에 답해요.',
    roleCharacter: 'a meeting participant asking for your opinion',
    icon: Icons.record_voice_over_outlined,
  ),
];

const List<RoleplayScenario> koRoleplayScenarios = <RoleplayScenario>[
  RoleplayScenario(
    id: 'cafe_polite_order',
    title: 'Polite cafe order',
    description: 'Order, ask for options, and close politely in Korean.',
    descriptionKo: '한국어로 주문하고 선택지를 물으며 공손하게 마무리해요.',
    roleCharacter:
        'a Korean cafe staff member helping with a polite drink order',
    icon: Icons.local_cafe_outlined,
  ),
  RoleplayScenario(
    id: 'front_desk_help',
    title: 'Front desk help',
    description: 'Ask for help with booking, directions, or check-in details.',
    descriptionKo: '예약, 길 안내, 체크인에 관해 도움을 요청해요.',
    roleCharacter:
        'a Korean front desk staff member helping with travel or check-in',
    icon: Icons.hotel_outlined,
  ),
  RoleplayScenario(
    id: 'self_introduction',
    title: 'Self-introduction',
    description: 'Introduce yourself with the right level of formality.',
    descriptionKo: '상황에 맞는 높임말로 자신을 소개해요.',
    roleCharacter:
        'a Korean classmate or colleague listening to a self-introduction',
    icon: Icons.badge_outlined,
  ),
  RoleplayScenario(
    id: 'workplace_greeting',
    title: 'Workplace greeting',
    description: 'Greet coworkers and make simple professional small talk.',
    descriptionKo: '동료에게 인사하고 가벼운 직장 대화를 나눠요.',
    roleCharacter:
        'a Korean coworker greeting the learner at work for the first time',
    icon: Icons.groups_2_outlined,
  ),
  RoleplayScenario(
    id: 'polite_request',
    title: 'Polite request',
    description: 'Ask for a favor, respond, and soften refusals naturally.',
    descriptionKo: '부탁하고 답하며 거절도 자연스럽게 완곡하게 표현해요.',
    roleCharacter:
        'a Korean acquaintance responding to a polite request or favor',
    icon: Icons.record_voice_over_outlined,
  ),
  RoleplayScenario(
    id: 'friend_catch_up',
    title: 'Friend catch-up',
    description: 'Talk casually about your day, plans, and opinions.',
    descriptionKo: '하루 일과와 계획, 생각을 편하게 이야기해요.',
    roleCharacter: 'a Korean friend having a casual catch-up conversation',
    icon: Icons.forum_outlined,
  ),
  RoleplayScenario(
    id: 'clinic_visit',
    title: 'Clinic visit',
    description: 'Explain symptoms and understand simple follow-up questions.',
    descriptionKo: '증상을 설명하고 간단한 추가 질문을 이해해요.',
    roleCharacter:
        'a Korean clinic receptionist or nurse asking practical questions',
    icon: Icons.local_hospital_outlined,
  ),
];

List<RoleplayScenario> roleplayPresetScenariosFor(
  LearningLanguageCode targetLanguage,
) {
  return switch (targetLanguage) {
    LearningLanguageCode.ko => koRoleplayScenarios,
    LearningLanguageCode.en => enRoleplayScenarios,
    LearningLanguageCode.zh => enRoleplayScenarios,
  };
}

String roleplayCustomSituationHintFor(LearningLanguageCode targetLanguage) {
  return switch (targetLanguage) {
    LearningLanguageCode.ko => 'I am asking a clinic receptionist for help.',
    LearningLanguageCode.en => 'I am checking in at a hotel front desk.',
    LearningLanguageCode.zh => 'I am asking for help at a front desk.',
  };
}
