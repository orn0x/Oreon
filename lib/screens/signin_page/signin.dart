import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:oreon/main.dart';
import 'package:oreon/providers/providers.dart';
import 'package:provider/provider.dart';
import 'dart:convert'; // for utf8.encode
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart'; // for hashing algorithms


class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;
  late TextEditingController _userSeed;
  late TextEditingController _userUUID;
  
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _nameController = TextEditingController();
    _usernameController = TextEditingController();
    _phoneController = TextEditingController();
    _userSeed = TextEditingController();
    _userUUID = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _userSeed.dispose();
    _userUUID.dispose();
    super.dispose();
  }

  String generateSha256Hash(String input) {
    return sha256.convert(utf8.encode(input.trim())).toString();
}


  Future<void> _handleSignIn() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Simulate authentication delay
      await Future.delayed(const Duration(seconds: 2));

      // Update user provider with sign-in data
      if(_isSignUp && (_nameController.text.isEmpty || _emailController.text.isEmpty || _phoneController.text.isEmpty)) {
        _showSnackBar('Please fill in all fields for sign up');
        setState(() => _isLoading = false);
        return;
      }
      if(!_isSignUp) {
        if(_usernameController.text != prefs.getString('username') || _passwordController.text != prefs.getString('password').toString()) {
          _showSnackBar('Invalid username or password');
          setState(() => _isLoading = false);
          return;
        }
      }

      if (mounted && context.mounted) {
        final userProvider = context.read<UserProvider>();
        await userProvider.updateUserData(
          name: _isSignUp ? _nameController.text : 'User',
          bio: 'Welcome to Oreon',
          username: _usernameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          seed: generateSha256Hash(_usernameController.text),
          uuid: Uuid().v4().toString(),
        );

        if (mounted && context.mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Authentication failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.teal,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      body: Stack(
        children: [
          // Background glow effect
          const _AuthBackgroundGlow(),
          
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    
                    // App logo/title
                    Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.transparent,
                          radius: 48,
                          child: Image.asset(
                          'assets/logo/logo_white_wout.png',
                          width: 100,
                          height: 100,
                          ),
                        ),
                        const Text(
                          'Oreon',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isSignUp ? 'Create your account' : 'Welcome back',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 60),

                    // Sign Up Name Field
                    if (_isSignUp)
                      Column(
                        children: [
                          _GlassmorphicTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            hint: 'Enter your name',
                            icon: Icons.person_outline,
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),

                      // Username field
                      _GlassmorphicTextField(
                         controller: _usernameController,
                         label: 'Username',
                         hint: 'Enter your username',
                         icon: LucideIcons.user,
                         keyboardType: TextInputType.emailAddress,
                         enabled: !_isLoading,
                       ),

                    const SizedBox(height: 16),

                    if(_isSignUp)
                      Column(
                        children: [
                          // Email field
                          _GlassmorphicTextField(
                            controller: _emailController,
                            label: 'Email',
                            hint: 'Enter your email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_isLoading,
                          ),

                           const SizedBox(height: 16),

                          _GlassmorphicTextField(
                            controller: _phoneController,
                            label: 'Phone',
                            hint: 'Enter your phone number',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),

                    // Password field
                    _GlassmorphicPasswordField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'Enter your password',
                      obscure: _obscurePassword,
                      onToggleObscure: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      enabled: !_isLoading,
                    ),

                    const SizedBox(height: 24),

                    const SizedBox(height: 32),

                    // Sign in/up button
                    _GradientButton(
                      text: _isSignUp ? 'Sign Up' : 'Sign In',
                      isLoading: _isLoading,
                      onPressed: _handleSignIn,
                    ),

                    const SizedBox(height: 20),

                    // Toggle between sign in and sign up
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isSignUp ? 'Already have an account? ' : 'Don\'t have an account? ',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _isSignUp = !_isSignUp;
                                    _nameController.clear();
                                  });
                                },
                          child: Text(
                            _isSignUp ? 'Sign In' : 'Sign Up',
                            style: const TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Glassmorphic text field
class _GlassmorphicTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool enabled;

  const _GlassmorphicTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: controller,
                enabled: enabled,
                keyboardType: keyboardType,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    icon,
                    color: Colors.teal.withOpacity(0.7),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Glassmorphic password field
class _GlassmorphicPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final bool enabled;

  const _GlassmorphicPasswordField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.obscure,
    required this.onToggleObscure,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: controller,
                enabled: enabled,
                obscureText: obscure,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: Colors.teal.withOpacity(0.7),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.teal.withOpacity(0.7),
                    ),
                    onPressed: enabled ? onToggleObscure : null,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Gradient button
class _GradientButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.text,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.teal.withOpacity(0.9),
            Colors.cyan.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.9),
                      ),
                    ),
                  )
                : Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// Background glow effect
class _AuthBackgroundGlow extends StatelessWidget {
  const _AuthBackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dark background
        Container(
          color: const Color(0xFF0D0F14),
        ),
        
        // Animated glow orbs
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.teal.withOpacity(0.15),
                  Colors.teal.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -150,
          left: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.cyan.withOpacity(0.1),
                  Colors.cyan.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
