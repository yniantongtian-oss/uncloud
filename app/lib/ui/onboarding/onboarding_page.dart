import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../pairing/pairing_page.dart';

/// Three-page intro: privacy → direct link → local AI, then pairing.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.onDone});

  /// Called when onboarding is finished (or skipped); [OnboardingGate]
  /// persists the flag and swaps in the home shell.
  final VoidCallback? onDone;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finish() {
    // Do not call onDone before pushing pairing — onDone unmounts this page
    // (OnboardingGate swaps in HomeShell) and then Navigator.of(context) throws.
    final complete = widget.onDone;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => PairingPage(
          onDone: () {
            Navigator.of(ctx).pop();
            complete?.call();
          },
        ),
      ),
    );
  }

  void _next() {
    if (_page >= 2) {
      _finish();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = [
      _Slide(icon: Icons.lock_outline, title: l10n.onbTitle1, body: l10n.onbBody1),
      _Slide(icon: Icons.devices, title: l10n.onbTitle2, body: l10n.onbBody2),
      _Slide(icon: Icons.psychology_alt_outlined, title: l10n.onbTitle3, body: l10n.onbBody3),
    ];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(l10n.onbSkip),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => pages[i],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _page == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _page == i ? scheme.primary : scheme.outlineVariant,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: _next,
                    child: Text(_page >= 2 ? l10n.onbGetStarted : l10n.onbNext),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.tagline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
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

class _Slide extends StatelessWidget {
  const _Slide({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
