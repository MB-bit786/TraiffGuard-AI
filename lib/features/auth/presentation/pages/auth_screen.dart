import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hscode_auditor/core/util/auth_service.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import 'package:hscode_auditor/core/constants/auth_error_constants.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleView() {
    setState(() {
      _isLogin = !_isLogin;
      _formKey.currentState?.reset();
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
    
    if (_isLogin) {
      _animationController.reverse();
    } else {
      _animationController.forward();
    }
  }

  void _handleAuthException(FirebaseAuthException e) {
    final String message = AuthErrorConstants.getMessage(e.code);

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
          backgroundColor: TariffColors.navyElevated,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(20),
        ),
      );
    }
  }

  Future<void> _submitAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      
      if (_isLogin) {
        await authService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        ref.read(registrationInProgressProvider.notifier).state = true;
        
        try {
          await authService.registerWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _nameController.text.trim(),
          );
          
          if (mounted) {
            _toggleView();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Verification protocol initiated. Please sign in to activate.'),
                backgroundColor: TariffColors.greenVerified,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } finally {
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            ref.read(registrationInProgressProvider.notifier).state = false;
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthException(e);
    } catch (e) {
      debugPrint('[AUTH] Unknown Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TariffColors.navyDeep,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [
              const Color(0xFF1E3A63).withValues(alpha: 0.3),
              TariffColors.navyDeep,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBrandingHeader(),
                    const SizedBox(height: 54),
                    
                    Text(
                      _isLogin ? 'OPERATOR AUTHENTICATION' : 'ENROLL NEW OPERATOR',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: TariffColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: Column(
                        children: [
                          if (!_isLogin) ...[
                            _buildTextField(
                              controller: _nameController,
                              label: 'FULL NAME',
                              hint: 'Enter your identity as on ID',
                              icon: Icons.badge_outlined,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required for clearance' : null,
                            ),
                            const SizedBox(height: 20),
                          ],
                          _buildTextField(
                            controller: _emailController,
                            label: 'CORPORATE EMAIL',
                            hint: 'operator@tariffguard.ai',
                            icon: Icons.alternate_email_rounded,
                            inputType: TextInputType.emailAddress,
                            validator: (v) {
                              final emailRegex = RegExp(r"^[a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
                              if (v == null || !emailRegex.hasMatch(v)) {
                                return 'Please enter a valid business email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _passwordController,
                            label: 'SECURITY PASSWORD',
                            hint: 'Minimum 6 character protocol',
                            icon: Icons.lock_clock_outlined,
                            isPassword: true,
                            obscure: _obscurePassword,
                            toggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                            validator: (v) => (v == null || v.length < 6) ? 'Security threshold: Min 6 characters' : null,
                          ),
                          if (!_isLogin) ...[
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: _confirmPasswordController,
                              label: 'CONFIRM SECURITY TOKEN',
                              hint: 'Repeat your password',
                              icon: Icons.verified_user_outlined,
                              isPassword: true,
                              obscure: _obscureConfirmPassword,
                              toggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              validator: (v) {
                                if (v != _passwordController.text) return 'Passwords do not match';
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    _buildPrimaryButton(),
                    const SizedBox(height: 28),
                    _buildViewToggleLink(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandingHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: TariffColors.amberPending.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: TariffColors.amberPending.withValues(alpha: 0.3), width: 1.5),
          ),
          child: const Icon(
            Icons.shield_rounded,
            color: TariffColors.amberPending,
            size: 48,
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'TariffGuard Intelligence',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: TariffColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'SECURE BORDER CLEARANCE PROTOCOL',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: TariffColors.amberPending.withValues(alpha: 0.8),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? toggleObscure,
    TextInputType inputType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      obscureText: isPassword && obscure,
      validator: validator,
      style: const TextStyle(color: TariffColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: TariffColors.textMuted),
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 20,
                color: TariffColors.textMuted,
              ),
              onPressed: toggleObscure,
            )
          : null,
        labelStyle: const TextStyle(color: TariffColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0),
        hintStyle: const TextStyle(color: TariffColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: TariffColors.navySurface,
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TariffColors.inputBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TariffColors.inputBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TariffColors.amberPending, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TariffColors.crimsonRisk, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TariffColors.crimsonRisk, width: 2),
        ),
        errorStyle: const TextStyle(color: TariffColors.crimsonRisk, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return SizedBox(
      height: 62,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitAuth,
        style: ElevatedButton.styleFrom(
          backgroundColor: TariffColors.amberPending,
          foregroundColor: TariffColors.navyDeep,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isLoading 
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3.5, valueColor: AlwaysStoppedAnimation(TariffColors.navyDeep)),
            )
          : Text(
              _isLogin ? 'SECURE AUTHENTICATION' : 'INITIALIZE ACCOUNT',
              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 14),
            ),
      ),
    );
  }

  Widget _buildViewToggleLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLogin ? "NEW OPERATOR?" : "EXISTING OPERATOR?",
          style: const TextStyle(color: TariffColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: _isLoading ? null : _toggleView,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: Text(
            _isLogin ? 'REQUEST ACCESS' : 'LOG IN',
            style: const TextStyle(
              color: TariffColors.amberPending,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
