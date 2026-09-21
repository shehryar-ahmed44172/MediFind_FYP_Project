import 'package:flutter/material.dart';

/// One page of the first-run walkthrough / one step in the help screen.
class GuideStep {
  final IconData icon;
  final String title;

  /// One or two short sentences. Written for someone who has never used the
  /// app — no jargon, no reference to code or screens by internal name.
  final String body;

  /// Optional bullets, shown under the body.
  final List<String> points;

  const GuideStep({
    required this.icon,
    required this.title,
    required this.body,
    this.points = const [],
  });
}

class GuideSection {
  final String title;
  final List<GuideStep> steps;
  const GuideSection(this.title, this.steps);
}

/// Everything the guide shows, per role. Deaf patients get their own wording
/// because their emergency never depends on hearing or speaking.
class GuideContent {
  static String roleLabel(String role, bool isDeaf) => switch (role) {
        'CAREGIVER' => 'Caregiver',
        'RESPONDER' => 'Responder',
        _ => isDeaf ? 'Deaf patient' : 'Patient',
      };

  /// 5 pages shown once, right after the first sign-in.
  static List<GuideStep> walkthrough(String role, bool isDeaf) {
    switch (role) {
      case 'CAREGIVER':
        return const [
          GuideStep(
            icon: Icons.shield_outlined,
            title: 'You watch over your people',
            body: 'MediFind tells you the moment someone you care for asks for emergency help, '
                'and lets you follow everything until help arrives.',
          ),
          GuideStep(
            icon: Icons.person_add_alt_1_outlined,
            title: 'Link a patient first',
            body: 'Send a link request to the person you care for. Once they accept, '
                'their emergencies reach you.',
            points: ['Open "Link a patient"', 'Enter their MediFind email', 'Wait for them to accept'],
          ),
          GuideStep(
            icon: Icons.notifications_active_outlined,
            title: 'You are alerted at once',
            body: 'When your patient sends an SOS, your phone alerts you immediately — '
                'even if the app is closed.',
          ),
          GuideStep(
            icon: Icons.map_outlined,
            title: 'Follow it live',
            body: 'See where your patient is, which responder is coming and how far away they are, '
                'on the same live map the patient sees.',
          ),
          GuideStep(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Stay in touch',
            body: 'Message or call your patient in one tap, and reach the responder while the '
                'emergency is open.',
          ),
        ];
      case 'RESPONDER':
        return const [
          GuideStep(
            icon: Icons.local_hospital_outlined,
            title: 'You are the help',
            body: 'MediFind sends nearby emergencies straight to you, with the patient\'s location '
                'and medical details, so you can leave without asking questions.',
          ),
          GuideStep(
            icon: Icons.toggle_on_outlined,
            title: 'Go online to receive requests',
            body: 'You only get emergencies while you are online. Turn it off when your shift ends.',
          ),
          GuideStep(
            icon: Icons.check_circle_outline_rounded,
            title: 'Accept a request',
            body: 'You see the emergency type, distance and the patient\'s medical summary. '
                'Accept and navigation opens right away.',
            points: ['First responder to accept gets the case', 'Others are told it was taken'],
          ),
          GuideStep(
            icon: Icons.hearing_disabled_outlined,
            title: 'Some patients cannot hear or speak',
            body: 'A deaf patient is clearly marked. Use the text chat — they can answer instantly '
                'with one-tap phrases, and video calls work for sign language.',
          ),
          GuideStep(
            icon: Icons.done_all_rounded,
            title: 'Finish the case',
            body: 'Mark the emergency resolved when the patient is handed over. The chat closes '
                'and the patient can rate your response.',
          ),
        ];
      default:
        if (isDeaf) {
          return const [
            GuideStep(
              icon: Icons.favorite_border_rounded,
              title: 'Help without speaking',
              body: 'MediFind is built for deaf and hard of hearing people. Nothing here needs you '
                  'to hear or talk — one tap brings an ambulance to you.',
            ),
            GuideStep(
              icon: Icons.touch_app_outlined,
              title: 'Hold SOS for 2 seconds',
              body: 'Pick what kind of emergency it is, or let the app suggest it. '
                  'You have 60 seconds to cancel a mistake.',
            ),
            GuideStep(
              icon: Icons.flash_on_outlined,
              title: 'Alerts you can see and feel',
              body: 'Every update flashes on your screen and vibrates. Nothing important is ever '
                  'sound only.',
            ),
            GuideStep(
              icon: Icons.quickreply_outlined,
              title: 'Talk your way',
              body: 'Chat with your responder in text, send a ready-made phrase in one tap, '
                  'or start a video call for sign language.',
              points: ['Voice calls are switched off for you', 'Edit your phrases any time'],
            ),
            GuideStep(
              icon: Icons.badge_outlined,
              title: 'Show people around you',
              body: 'Open "Show to people nearby" to display a full-screen card that explains '
                  'you are deaf and what help you need.',
            ),
          ];
        }
        return const [
          GuideStep(
            icon: Icons.favorite_border_rounded,
            title: 'Help in one tap',
            body: 'MediFind sends your location and medical details to the nearest verified '
                'motorbike ambulance — no explaining, no searching for a number.',
          ),
          GuideStep(
            icon: Icons.touch_app_outlined,
            title: 'Hold SOS for 2 seconds',
            body: 'Choose the kind of emergency, or let the app suggest it from your symptoms. '
                'You have 60 seconds to cancel if it was a mistake.',
          ),
          GuideStep(
            icon: Icons.map_outlined,
            title: 'Watch help arrive',
            body: 'When a responder accepts, you see who is coming and how far away they are, '
                'moving live on the map.',
          ),
          GuideStep(
            icon: Icons.medical_information_outlined,
            title: 'Keep your Medical ID ready',
            body: 'Blood group, allergies and medicines go to the responder with every SOS. '
                'Fill it in once, today, while you are calm.',
          ),
          GuideStep(
            icon: Icons.people_outline_rounded,
            title: 'Add your family',
            body: 'Linked caregivers are alerted the moment you send an SOS and can follow the '
                'same live map.',
          ),
        ];
    }
  }

  /// The full help screen: the walkthrough steps plus what people ask later.
  static List<GuideSection> help(String role, bool isDeaf) {
    final steps = walkthrough(role, isDeaf);
    final title = switch (role) {
      'CAREGIVER' => 'Caring for someone',
      'RESPONDER' => 'Responding to emergencies',
      _ => 'Getting help',
    };

    return [
      GuideSection(title, steps),
      const GuideSection('Good to know', [
        GuideStep(
          icon: Icons.lock_outline_rounded,
          title: 'Who can see your details',
          body: 'Your phone number and medical details are shared only with the responder handling '
              'your emergency, and with caregivers you linked yourself. When the emergency ends, '
              'access ends too.',
        ),
        GuideStep(
          icon: Icons.location_on_outlined,
          title: 'Keep location and notifications on',
          body: 'MediFind needs your location to send help to the right place, and notifications '
              'to reach you when the app is closed.',
        ),
        GuideStep(
          icon: Icons.battery_charging_full_rounded,
          title: 'Let the app run in the background',
          body: 'If your phone is set to close apps aggressively, allow MediFind to keep running '
              'so alerts still arrive.',
        ),
        GuideStep(
          icon: Icons.phone_in_talk_outlined,
          title: 'If there is no internet',
          body: 'MediFind needs a data connection. With no internet, call 1122 directly — the app '
              'shows that option on screen.',
        ),
      ]),
      const GuideSection('One network, four roles', [
        GuideStep(
          icon: Icons.favorite_border_rounded,
          title: 'Patients',
          body: 'Send an SOS in one tap, share their medical profile automatically and follow the '
              'responder live.',
        ),
        GuideStep(
          icon: Icons.two_wheeler_outlined,
          title: 'Responders',
          body: 'Verified paramedics on motorbike ambulances who receive nearby emergencies with '
              'location and medical details.',
        ),
        GuideStep(
          icon: Icons.people_outline_rounded,
          title: 'Caregivers',
          body: 'Family members linked to a patient. They are alerted at once and watch the same '
              'live map.',
        ),
        GuideStep(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Admins',
          body: 'Verify every responder before they can accept emergencies, and monitor the system '
              'from the web portal.',
        ),
      ]),
    ];
  }
}
