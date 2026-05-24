import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../shared/theme/kiss_theme.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/mesh_background.dart';
import '../home/home_shell.dart';

class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KissTheme.of(context);
    return Scaffold(
      body: MeshBackground(
        intensity: 0.8,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(KissSpacing.x3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: KissGradients.brand,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: KissShadows.glowPink,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'K',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontFamily: 'Unbounded',
                      ),
                    ),
                  ),
                  const SizedBox(height: KissSpacing.x3),
                  Text(
                    'Привет от Kiss VPN',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: KissSpacing.sm),
                  Text(
                    'Вставьте ссылку с подпиской из личного кабинета kissmain.ru — остальное за нас.',
                    style: TextStyle(
                      color: t.textMid,
                      height: 1.5,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: KissSpacing.x3),
                  GradientButton(
                    label: 'Продолжить',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () {
                      ref.read(activeTabProvider.notifier).state = HomeTab.subscription;
                      Navigator.of(context)
                          .pushReplacementNamed(AppRouter.home);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
