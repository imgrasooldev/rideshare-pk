import 'package:flutter/material.dart';

import '../../core/widgets/gradient_button.dart';

/// First-launch showcase. Three slides introduce the marketplace, then hands
/// off to the auth flow. Shown once (gated by shared_preferences upstream).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.badges,
  });
  final IconData icon;
  final String title;
  final String description;
  final List<_Badge> badges;
}

class _Badge {
  const _Badge(this.icon, this.color, this.tint);
  final IconData icon;
  final Color color;
  final Color tint;
}

const _slides = <_OnboardingSlide>[
  _OnboardingSlide(
    icon: Icons.directions_car_filled_rounded,
    title: 'One app, every ride',
    description:
        'Office pick & drop, city travel, rent a car, airport shuttle and more — all in one place.',
    badges: [
      _Badge(Icons.two_wheeler_rounded, Color(0xFF12A46B), Color(0xFFDFF6EC)),
      _Badge(Icons.flight_rounded, Color(0xFF3B72E0), Color(0xFFE4EEFE)),
      _Badge(Icons.local_shipping_outlined, Color(0xFFE24657), Color(0xFFFDE7EA)),
    ],
  ),
  _OnboardingSlide(
    icon: Icons.groups_2_rounded,
    title: 'Share & save up to 60%',
    description:
        'Match with commuters on your daily route and split the cost — cash only, no wallet needed.',
    badges: [
      _Badge(Icons.savings_outlined, Color(0xFFE19700), Color(0xFFFFF3D6)),
      _Badge(Icons.schedule_rounded, Color(0xFF1E88D6), Color(0xFFE1F1FD)),
      _Badge(Icons.repeat_rounded, Color(0xFF7C5AE0), Color(0xFFEDE9FD)),
    ],
  ),
  _OnboardingSlide(
    icon: Icons.verified_user_rounded,
    title: 'Safe & women-friendly',
    description:
        'Verified drivers, ladies-only rides and live trip tracking — travel with peace of mind.',
    badges: [
      _Badge(Icons.favorite_rounded, Color(0xFFD6488B), Color(0xFFFCE7F0)),
      _Badge(Icons.location_on_rounded, Color(0xFF12A46B), Color(0xFFDFF6EC)),
      _Badge(Icons.star_rounded, Color(0xFFE19700), Color(0xFFFFF3D6)),
    ],
  ),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      widget.onDone();
    } else {
      _controller.nextPage(
          duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedOpacity(
                opacity: _isLast ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: TextButton(
                  onPressed: _isLast ? null : widget.onDone,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: active
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withValues(alpha: 0.22),
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GradientButton(
                label: _isLast ? 'Get started' : 'Next',
                icon: _isLast ? Icons.arrow_forward_rounded : null,
                onPressed: _next,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 280,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(56),
                    color: primary.withValues(alpha: 0.08),
                  ),
                  child: Icon(slide.icon, size: 104, color: primary),
                ),
                Positioned(top: 18, right: 30, child: _badge(slide.badges[0])),
                Positioned(bottom: 40, right: 12, child: _badge(slide.badges[1])),
                Positioned(bottom: 30, left: 24, child: _badge(slide.badges[2])),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(slide.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
          const SizedBox(height: 12),
          Text(slide.description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline, height: 1.5)),
        ],
      ),
    );
  }

  Widget _badge(_Badge b) => Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Color(0x14101828), blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: b.tint, shape: BoxShape.circle),
          child: Icon(b.icon, color: b.color, size: 20),
        ),
      );
}
