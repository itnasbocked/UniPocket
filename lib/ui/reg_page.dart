import 'package:dm/data/database/database_helper.dart';
import 'package:flutter/material.dart';

class RegPage extends StatefulWidget {
  const RegPage({super.key});

  @override
  State<RegPage> createState() => _RegPageState();
}

class _RegPageState extends State<RegPage> {
  final _usuarioCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _ingresoCtrl = TextEditingController();

  bool _procesando = false;

  bool _obscurePass = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "UniPocket",
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2962FF),
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 40),

                Container(
                  padding: const EdgeInsets.all(32.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
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
                          "Crear Cuenta",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1D1D1D),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      _buildInputLabel("Usuario"),
                      _buildTextField(
                        hint: "Tu nombre",
                        icon: Icons.person_outline,
                        controller: _usuarioCtrl,
                      ),
                      const SizedBox(height: 20),

                      _buildInputLabel("Correo electrónico"),
                      _buildTextField(
                        hint: "tu@correo.com",
                        icon: Icons.email_outlined,
                        controller: _correoCtrl,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),

                      _buildInputLabel("Contraseña"),
                      _buildTextField(
                        hint: "........",
                        icon: Icons.lock_outline,
                        controller: _passCtrl,
                        isPassword: true,
                      ),
                      const SizedBox(height: 20),

                      _buildInputLabel("Confirmar contraseña"),
                      _buildTextField(
                        hint: "........",
                        icon: Icons.lock_outline,
                        controller: _confirmPassCtrl,
                        isPassword: true,
                      ),
                      const SizedBox(height: 35),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2962FF),
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: const Color(0xFF2962FF).withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _procesando ? null : _ejecutarRegistro,
                          child: _procesando 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "REGISTRARSE",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 20),
                                ],
                              ),
                        ),
                      ),
                      const SizedBox(height: 25),

                      Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context); 
                          },
                          child: const Text(
                            "¿Ya tienes cuenta? Inicia sesión",
                            style: TextStyle(
                              color: Color(0xFF2962FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
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
      ),
    );
  }

  Future<void> _ejecutarRegistro() async {
    String nombre = _usuarioCtrl.text.trim();
    String correo = _correoCtrl.text.trim();
    String pass = _passCtrl.text;
    String confirmPass = _confirmPassCtrl.text;
    String ingresoTexto = _ingresoCtrl.text.trim();

    if (nombre.isEmpty || correo.isEmpty || pass.isEmpty || ingresoTexto.isEmpty) {
      _mostrarMensaje("Por favor, llena todos los campos");
      return;
    }

    if (pass != confirmPass) {
      _mostrarMensaje("Las contraseñas no coinciden");
      return;
    }

    double ingresoPesos = double.tryParse(ingresoTexto) ?? -1;
    if (ingresoPesos < 0) {
      _mostrarMensaje("Ingresa un monto válido para el ingreso mensual");
      return;
    }

    int ingresoCentavos = (ingresoPesos * 100).toInt();

    setState(() => _procesando = true);

    String resultado = await DatabaseHelper.instance.registrarUsuario(
      nombre, 
      correo, 
      pass, 
      ingresoCentavos
    );

    setState(() => _procesando = false);

    if (resultado == "Exito") {
      _mostrarMensaje("Cuenta creada exitosamente. Por favor inicia sesión.");
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      _mostrarMensaje(resultado);
    }
  }

  // Función auxiliar para mostrar notificaciones en pantalla
  void _mostrarMensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePass : false,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black38),
          prefixIcon: Icon(icon, color: const Color(0xFF8294C4)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          suffixIcon: isPassword 
            ? IconButton(
                icon: Icon(
                  _obscurePass ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF8294C4),
                ),
                onPressed: () {
                  setState(() => _obscurePass = !_obscurePass);
                },
              )
            : null,
      ),
    ));
  }

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _correoCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _ingresoCtrl.dispose();
    super.dispose();
  }
}