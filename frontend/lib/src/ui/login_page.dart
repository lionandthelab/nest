import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../state/nest_controller.dart';
import 'nest_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.controller});

  final NestController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'lionandthelab@gmail.com');
  final _passwordController = TextEditingController(text: 'dmltjr12');
  final _confirmPasswordController = TextEditingController();
  bool _isSignUpMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    try {
      if (_isSignUpMode) {
        await widget.controller.signUp(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await widget.controller.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.controller.statusMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const _WarmBackground(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0.94, end: 1),
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: AnimatedBuilder(
                        animation: widget.controller,
                        builder: (context, _) {
                          return Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppConfig.appName,
                                  style: theme.textTheme.displayMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  AppConfig.brandLine,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: NestColors.deepWood.withValues(
                                      alpha: 0.72,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    hintText: 'you@nest.local',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return '이메일을 입력하세요.';
                                    }
                                    if (!value.contains('@')) {
                                      return '유효한 이메일 형식이 아닙니다.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Password',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return '비밀번호를 입력하세요.';
                                    }
                                    if (_isSignUpMode &&
                                        value.trim().length < 8) {
                                      return '비밀번호는 8자 이상으로 입력하세요.';
                                    }
                                    return null;
                                  },
                                  onFieldSubmitted: (_) => _onSubmit(),
                                ),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SizeTransition(
                                        sizeFactor: animation,
                                        axisAlignment: -1,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _isSignUpMode
                                      ? Column(
                                          key: const ValueKey('signup-confirm'),
                                          children: [
                                            const SizedBox(height: 14),
                                            TextFormField(
                                              controller:
                                                  _confirmPasswordController,
                                              obscureText: true,
                                              decoration: const InputDecoration(
                                                labelText: 'Password 확인',
                                              ),
                                              validator: (value) {
                                                if (!_isSignUpMode) {
                                                  return null;
                                                }
                                                if (value == null ||
                                                    value.trim().isEmpty) {
                                                  return '비밀번호 확인을 입력하세요.';
                                                }
                                                if (value !=
                                                    _passwordController.text) {
                                                  return '비밀번호가 일치하지 않습니다.';
                                                }
                                                return null;
                                              },
                                              onFieldSubmitted: (_) =>
                                                  _onSubmit(),
                                            ),
                                          ],
                                        )
                                      : const SizedBox(
                                          key: ValueKey('signin-confirm-empty'),
                                        ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: widget.controller.isBusy
                                      ? null
                                      : _onSubmit,
                                  icon: widget.controller.isBusy
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.login),
                                  label: Text(_isSignUpMode ? '회원가입' : '로그인'),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: widget.controller.isBusy
                                      ? null
                                      : () {
                                          setState(() {
                                            _isSignUpMode = !_isSignUpMode;
                                            _confirmPasswordController.clear();
                                          });
                                        },
                                  child: Text(
                                    _isSignUpMode
                                        ? '이미 계정이 있나요? 로그인'
                                        : '계정이 없나요? 회원가입',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  widget.controller.statusMessage,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: NestColors.deepWood.withValues(
                                      alpha: 0.72,
                                    ),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarmBackground extends StatelessWidget {
  const _WarmBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF5EF),
            NestColors.creamyWhite,
            Color(0xFFF2ECE4),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -110,
            right: -70,
            child: _GlowBlob(
              size: 260,
              color: NestColors.dustyRose.withValues(alpha: 0.26),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -90,
            child: _GlowBlob(
              size: 320,
              color: NestColors.mutedSage.withValues(alpha: 0.21),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 70, spreadRadius: 20)],
      ),
    );
  }
}
