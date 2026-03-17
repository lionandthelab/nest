import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _isSignUpMode = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      HapticFeedback.lightImpact();
      return;
    }

    try {
      if (_isSignUpMode) {
        await widget.controller.signUp(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _nicknameController.text,
        );
        if (mounted) {
          HapticFeedback.mediumImpact();
        }
      } else {
        await widget.controller.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    } catch (_) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.controller.statusMessage)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onForgotPassword() async {
    final emailController = TextEditingController(text: _emailController.text);
    final requestedEmail = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('비밀번호 재설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '가입한 이메일 주소를 입력하면 비밀번호 재설정 링크를 보내드립니다.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '이메일',
                hintText: 'you@example.com',
                prefixIcon: Icon(Icons.email_outlined, size: 20),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(emailController.text.trim()),
            child: const Text('메일 보내기'),
          ),
        ],
      ),
    );
    emailController.dispose();

    if (requestedEmail == null || requestedEmail.isEmpty) return;

    try {
      await widget.controller.requestPasswordReset(email: requestedEmail);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('$requestedEmail으로 재설정 메일을 발송했습니다.')),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.controller.statusMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      body: Stack(
        children: [
          const _WarmBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset * 0.3),
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
                        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                        child: AnimatedBuilder(
                          animation: widget.controller,
                          builder: (context, _) {
                            return Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // ── Logo + Brand ──
                                  Center(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.asset(
                                        'assets/logo_square.png',
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    AppConfig.appName,
                                    style: theme.textTheme.displayMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    AppConfig.brandLine,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: NestColors.deepWood.withValues(alpha: 0.65),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 28),

                                  // ── Nickname (sign-up only) ──
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
                                            key: const ValueKey('signup-nickname'),
                                            children: [
                                              TextFormField(
                                                controller: _nicknameController,
                                                textInputAction: TextInputAction.next,
                                                autofillHints: const [AutofillHints.nickname],
                                                decoration: const InputDecoration(
                                                  labelText: '닉네임',
                                                  hintText: '앱에서 표시될 이름',
                                                  prefixIcon: Icon(Icons.person_outlined, size: 20),
                                                ),
                                                validator: (value) {
                                                  if (!_isSignUpMode) return null;
                                                  if (value == null || value.trim().isEmpty) {
                                                    return '닉네임을 입력하세요.';
                                                  }
                                                  if (value.trim().length < 2) {
                                                    return '닉네임은 2자 이상으로 입력하세요.';
                                                  }
                                                  return null;
                                                },
                                              ),
                                              const SizedBox(height: 14),
                                            ],
                                          )
                                        : const SizedBox(key: ValueKey('signin-nickname-empty')),
                                  ),

                                  // ── Email ──
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [AutofillHints.email],
                                    decoration: const InputDecoration(
                                      labelText: '이메일',
                                      hintText: 'you@example.com',
                                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return '이메일을 입력하세요.';
                                      }
                                      if (!value.contains('@') || !value.contains('.')) {
                                        return '유효한 이메일 형식이 아닙니다.';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),

                                  // ── Password ──
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    textInputAction: _isSignUpMode
                                        ? TextInputAction.next
                                        : TextInputAction.done,
                                    autofillHints: _isSignUpMode
                                        ? const [AutofillHints.newPassword]
                                        : const [AutofillHints.password],
                                    decoration: InputDecoration(
                                      labelText: '비밀번호',
                                      prefixIcon: const Icon(Icons.lock_outlined, size: 20),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          size: 20,
                                        ),
                                        onPressed: () => setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        }),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return '비밀번호를 입력하세요.';
                                      }
                                      if (_isSignUpMode && value.trim().length < 8) {
                                        return '비밀번호는 8자 이상으로 입력하세요.';
                                      }
                                      return null;
                                    },
                                    onFieldSubmitted: _isSignUpMode ? null : (_) => _onSubmit(),
                                  ),

                                  // ── Confirm Password (sign-up only) ──
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
                                                controller: _confirmPasswordController,
                                                obscureText: _obscureConfirm,
                                                textInputAction: TextInputAction.done,
                                                autofillHints: const [AutofillHints.newPassword],
                                                decoration: InputDecoration(
                                                  labelText: '비밀번호 확인',
                                                  prefixIcon: const Icon(Icons.lock_outlined, size: 20),
                                                  suffixIcon: IconButton(
                                                    icon: Icon(
                                                      _obscureConfirm
                                                          ? Icons.visibility_off_outlined
                                                          : Icons.visibility_outlined,
                                                      size: 20,
                                                    ),
                                                    onPressed: () => setState(() {
                                                      _obscureConfirm = !_obscureConfirm;
                                                    }),
                                                  ),
                                                ),
                                                validator: (value) {
                                                  if (!_isSignUpMode) return null;
                                                  if (value == null || value.trim().isEmpty) {
                                                    return '비밀번호 확인을 입력하세요.';
                                                  }
                                                  if (value != _passwordController.text) {
                                                    return '비밀번호가 일치하지 않습니다.';
                                                  }
                                                  return null;
                                                },
                                                onFieldSubmitted: (_) => _onSubmit(),
                                              ),
                                            ],
                                          )
                                        : const SizedBox(key: ValueKey('signin-confirm-empty')),
                                  ),
                                  const SizedBox(height: 24),

                                  // ── Submit ──
                                  SizedBox(
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: widget.controller.isBusy ? null : _onSubmit,
                                      child: widget.controller.isBusy
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              _isSignUpMode ? '회원가입' : '로그인',
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // ── Mode toggle ──
                                  TextButton(
                                    onPressed: widget.controller.isBusy
                                        ? null
                                        : () {
                                            setState(() {
                                              _isSignUpMode = !_isSignUpMode;
                                              _confirmPasswordController.clear();
                                              _nicknameController.clear();
                                              _obscureConfirm = true;
                                            });
                                          },
                                    child: Text(
                                      _isSignUpMode
                                          ? '이미 계정이 있나요? 로그인'
                                          : '계정이 없나요? 회원가입',
                                    ),
                                  ),
                                  if (!_isSignUpMode)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: widget.controller.isBusy
                                            ? null
                                            : _onForgotPassword,
                                        child: const Text('비밀번호를 잊으셨나요?'),
                                      ),
                                    ),

                                  // ── Version ──
                                  const SizedBox(height: 16),
                                  Text(
                                    'v${AppConfig.appVersion}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: NestColors.deepWood.withValues(alpha: 0.4),
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
    return SizedBox.expand(
      child: DecoratedBox(
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
