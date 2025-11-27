import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n.dart';
import 'state.dart';
import 'consciousness_registry.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final PageController _controller = PageController();
  int _index = 0;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _ageBand = '25_64';

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    final reg = await ConsciousnessRegistryStore.load();
    final current = reg.userProfile ??
        UserProfile(
          personality: '',
          allergies: '',
          preferences: '',
          location: '',
          interests: '',
          education: '',
          socials: '',
        );

    reg.userProfile = UserProfile(
      personality: current.personality,
      allergies: current.allergies,
      preferences: current.preferences,
      location: current.location,
      interests: current.interests,
      education: current.education,
      socials: current.socials,
      displayName: name.isEmpty ? current.displayName : name,
      ageBand: _ageBand,
      email: email.isEmpty ? current.email : email,
      phone: phone.isEmpty ? current.phone : phone,
    );
    await ConsciousnessRegistryStore.save(reg);
    ref.read(onboardingCompletedProvider.notifier).state = true;
  }

  void _next() {
    const totalPages = 4;
    if (_index < totalPages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  ref.read(onboardingCompletedProvider.notifier).state = true;
                },
                child: Text(strings.onboardingSkip),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  _OnboardingPage(
                    icon: Icons.hub_outlined,
                    title: strings.onboardingMissionTitle,
                    body: strings.onboardingMissionBody,
                  ),
                  _OnboardingPage(
                    icon: Icons.lock_outline,
                    title: strings.onboardingPrivacyTitle,
                    body: strings.onboardingPrivacyBody,
                  ),
                  _OnboardingPage(
                    icon: Icons.bubble_chart_outlined,
                    title: strings.onboardingQuickTitle,
                    body: strings.onboardingQuickBody,
                  ),
                  _ProfileOnboardingPage(
                    nameController: _nameController,
                    emailController: _emailController,
                    phoneController: _phoneController,
                    ageBand: _ageBand,
                    onAgeBandChanged: (value) {
                      setState(() {
                        _ageBand = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      4,
                      (i) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _index
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
                        ),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _next,
                    child: Text(
                      _index < 3
                          ? strings.onboardingNext
                          : strings.onboardingStart,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 72),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _ProfileOnboardingPage extends StatelessWidget {
  const _ProfileOnboardingPage({
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.ageBand,
    required this.onAgeBandChanged,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final String ageBand;
  final ValueChanged<String> onAgeBandChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Who should OMK protect?',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Name or nickname',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Age range',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('< 18'),
                selected: ageBand == 'under_18',
                onSelected: (_) => onAgeBandChanged('under_18'),
              ),
              ChoiceChip(
                label: const Text('18–24'),
                selected: ageBand == '18_24',
                onSelected: (_) => onAgeBandChanged('18_24'),
              ),
              ChoiceChip(
                label: const Text('25–64'),
                selected: ageBand == '25_64',
                onSelected: (_) => onAgeBandChanged('25_64'),
              ),
              ChoiceChip(
                label: const Text('65+'),
                selected: ageBand == '65_plus',
                onSelected: (_) => onAgeBandChanged('65_plus'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email (optional)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone / WhatsApp (optional)',
            ),
          ),
        ],
      ),
    );
  }
}
