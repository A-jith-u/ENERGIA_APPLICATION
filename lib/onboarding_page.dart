import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  bool _isLastPage = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDone() async {
    // Navigate directly to home without saving completion state
    // This ensures onboarding shows on every app launch
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: _controller,
              onPageChanged: (index) {
                setState(() {
                  _isLastPage = index == 2;
                });
              },
              children: const [
                _OnboardingScreen(
                  imageUrl: 'assets/images/onboarding-1.jpg',
                  title: 'Welcome to ENERGIA',
                  description:
                      'Your smart solution for monitoring and managing energy consumption across the campus.',
                  imageAlignment: Alignment.topCenter,
                ),
                _OnboardingScreen(
                  imageUrl: 'assets/images/onboarding-2.jpg',
                  title: 'Real-time Monitoring',
                  description:
                      'View live energy data for classrooms and facilities to help conserve energy.',
                ),
                _OnboardingScreen(
                  imageUrl: 'assets/images/onboarding-3.jpg',
                  title: 'Control & Optimize',
                  description:
                      'Manage the entire system, ensuring efficient energy use everywhere, from anywhere.',
                ),
              ],
            ),
            // Bottom Controls
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Skip button
                    TextButton(
                      onPressed: _onDone,
                      child: Text(
                        'SKIP',
                        style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
                      ),
                    ),

                    // Dot indicator
                    SmoothPageIndicator(
                      controller: _controller,
                      count: 3,
                      effect: ExpandingDotsEffect(
                        spacing: 8,
                        dotWidth: 10,
                        dotHeight: 10,
                        dotColor: colorScheme.onSurface.withOpacity(0.2),
                        activeDotColor: colorScheme.primary,
                      ),
                      onDotClicked: (index) => _controller.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      ),
                    ),

                    // Next or Done button
                    SizedBox(
                      width: 80,
                      child: _isLastPage
                          ? ElevatedButton(
                              onPressed: _onDone,
                              style: ElevatedButton.styleFrom(
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(16),
                              ),
                              child: const Icon(Icons.check_rounded),
                            )
                          : ElevatedButton(
                              onPressed: () {
                                _controller.nextPage(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeInOut,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(16),
                              ),
                              child: const Icon(Icons.arrow_forward_ios_rounded),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingScreen extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String description;
  final Alignment imageAlignment;

  const _OnboardingScreen({
    required this.imageUrl,
    required this.title,
    required this.description,
    this.imageAlignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Image
        Image.asset(
          imageUrl,
          fit: BoxFit.cover,
        ),
        // Frosted Glass Overlay
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withOpacity(0.2),
              ),
            ),
          ),
        ),
        // Content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Image in a Circle
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      imageUrl,
                      fit: BoxFit.cover,
                      alignment: imageAlignment,
                    ),
                  ),
                ),
                const Spacer(),
                // Text Content
                Text(
                  title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      const Shadow(
                        blurRadius: 10.0,
                        color: Colors.black54,
                        offset: Offset(2.0, 2.0),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  description,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    height: 1.5,
                     shadows: [
                      const Shadow(
                        blurRadius: 8.0,
                        color: Colors.black87,
                        offset: Offset(1.0, 1.0),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
