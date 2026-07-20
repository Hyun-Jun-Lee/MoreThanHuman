import 'package:flutter/material.dart';

class RoleplayScenario {
  const RoleplayScenario({
    required this.id,
    required this.title,
    required this.description,
    required this.roleCharacter,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final String roleCharacter;
  final IconData icon;
}

const List<RoleplayScenario> roleplayPresetScenarios = <RoleplayScenario>[
  RoleplayScenario(
    id: 'cafe_order',
    title: 'Cafe order',
    description: 'Order drinks, ask for options, and pay naturally.',
    roleCharacter: 'a friendly cafe barista taking an order',
    icon: Icons.local_cafe_outlined,
  ),
  RoleplayScenario(
    id: 'hotel_check_in',
    title: 'Hotel check-in',
    description: 'Confirm a booking and ask about hotel details.',
    roleCharacter: 'a hotel front desk staff member helping with check-in',
    icon: Icons.hotel_outlined,
  ),
  RoleplayScenario(
    id: 'airport_immigration',
    title: 'Airport immigration',
    description: 'Answer travel purpose and arrival questions.',
    roleCharacter: 'an airport immigration officer asking entry questions',
    icon: Icons.flight_land_outlined,
  ),
  RoleplayScenario(
    id: 'job_interview',
    title: 'Job interview',
    description: 'Practice answers about experience and strengths.',
    roleCharacter: 'a job interviewer asking practical interview questions',
    icon: Icons.work_outline_rounded,
  ),
  RoleplayScenario(
    id: 'meeting_small_talk',
    title: 'Meeting small talk',
    description: 'Warm up before a meeting with casual work chat.',
    roleCharacter: 'a coworker making small talk before a meeting',
    icon: Icons.groups_2_outlined,
  ),
  RoleplayScenario(
    id: 'friend_conversation',
    title: 'Friend conversation',
    description: 'Talk casually about your day, plans, and opinions.',
    roleCharacter: 'a close friend having a casual conversation',
    icon: Icons.forum_outlined,
  ),
  RoleplayScenario(
    id: 'meeting_opinion',
    title: 'Meeting opinion',
    description: 'Share an opinion and respond to follow-up questions.',
    roleCharacter: 'a meeting participant asking for your opinion',
    icon: Icons.record_voice_over_outlined,
  ),
];
