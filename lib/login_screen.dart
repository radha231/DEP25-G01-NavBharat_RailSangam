import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // For opening URLs
import './main.dart'; // Import main.dart where LoginPage is

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _errorMessage = '';

  // Function to launch IRCTC website
  Future<void> _launchIRCTCWebsite() async {
    final Uri irctcUrl = Uri.parse('https://www.irctc.co.in/');
    try {
      if (await canLaunchUrl(irctcUrl)) {
        await launchUrl(
            irctcUrl,
            mode: LaunchMode.externalApplication
        );
      } else {
        _showSnackBar('Could not launch IRCTC website');
      }
    } catch (e) {
      _showSnackBar('An error occurred while launching website');
    }
  }

  // Simple login validation
  void _login() {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    // Simple hardcoded credentials (replace with your desired logic)
    if (true || _emailController.text.trim() == 'user@example.com' &&
        _passwordController.text.trim() == 'password123') {
      // Successful login
      //Navigator.pushReplacementNamed(context, '/home');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()), // Navigate to LoginPage
      );
    } else {
      setState(() {
        _errorMessage = 'Invalid email or password';
        _isLoading = false;
      });
    }
  }

  // Utility method to show snackbar
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Text(
                    'Welcome to\nTrain Social',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 5,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Login',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),

                        // Email TextField
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            // Basic email validation
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password TextField
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        if (_errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Text(
                              _errorMessage,
                              style: TextStyle(color: Colors.red),
                            ),
                          ),

                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              _showSnackBar('Forgot Password feature coming soon');
                            },
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(color: Colors.blue[900]),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () {
                              if (_formKey.currentState!.validate()) {
                                _login();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: Colors.blue[900],
                            ),
                            child: _isLoading
                                ? CircularProgressIndicator(color: Colors.white)
                                : const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Ticket Booking Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _launchIRCTCWebsite,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: Colors.green[900],
                            ),
                            child: const Text(
                              'Book Train Ticket',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Register Option
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Don't have an account?"),
                            TextButton(
                              onPressed: () {
                                _showSnackBar('Registration feature coming soon');
                              },
                              child: Text(
                                'Register',
                                style: TextStyle(color: Colors.blue[900]),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
