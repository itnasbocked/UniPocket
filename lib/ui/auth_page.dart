import 'package:dm/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_screen.dart';
import '../data/database/database_helper.dart';
import 'reg_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  
  // Variable de estado para evitar que el usuario haga spam de clics
  bool _isLoading = false; 

  Future<void> _ejecutarLogin() async {
    String user = _userController.text.trim();
    String pass = _passController.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, llena todos los campos"), backgroundColor: AppColors.alerta)
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;
      
      final result = await db.query(
        'usuario',
        where: 'nombre = ? AND contrasena = ?', 
        whereArgs: [user, pass],
      );

      if (result.isNotEmpty) {
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('userId', result.first['id'] as int); 
        await prefs.setBool('isLoggedIn', true);
        DatabaseHelper.instance.userId = result.first['id'] as int;

        _entrarAlSistema();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Usuario o contraseña incorrectos"), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error interno: $e"), backgroundColor: Colors.red)
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _entrarAlSistema() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "UniPocket",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primario,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 40),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                decoration: BoxDecoration(
                  color: AppColors.fondo,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        "Bienvenido",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 35),

                    _buildInputLabel("Usuario"),
                    const SizedBox(height: 8),
                    _buildTextField(_userController, "Tu nombre de usuario", Icons.person_outline, false),

                    const SizedBox(height: 24),

                    _buildInputLabel("Contraseña"),
                    const SizedBox(height: 8),
                    _buildTextField(_passController, "••••••••", Icons.lock_outline, true),

                    const SizedBox(height: 32),

                    Center(
                      child: GestureDetector(
                        onTap: _isLoading ? null : _ejecutarLogin,
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _isLoading ? Colors.grey : primaryBlue,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isLoading 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "INICIAR SESIÓN",
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1),
                                    ),
                                    SizedBox(width: 12),
                                    Icon(Icons.arrow_forward_rounded, color: Colors.white),
                                  ],
                                ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) => const RegPage()));
                        },
                        child: Text(
                          "¿No tienes cuenta? Regístrate",
                          style: TextStyle(color: primaryBlue.withOpacity(0.8), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInputLabel(String text) {
    return Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: labelColor));
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, bool isPass) {
    return TextField(
      controller: controller,
      obscureText: isPass,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryBlue.withOpacity(0.5)),
        filled: true,
        fillColor: backgroundColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
      ),
    );
  }
}