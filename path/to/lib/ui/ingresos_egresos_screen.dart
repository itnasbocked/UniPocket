import 'package:flutter/material.dart';
import '../data/database/database_helper.dart';
import '../data/models/ingresos-egresos_model.dart';
import '../logic/movimiento_controller.dart';

class IngresosEgresosScreen extends StatefulWidget {
  const IngresosEgresosScreen({super.key});

  @override
  State<IngresosEgresosScreen> createState() => IngresosEgresosScreenState();
}

class HistorialScreen extends StatefulWidget {
  final List<Movimiento> movimientos;

  const HistorialScreen(this.movimientos, {super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final MovimientoController _logic = MovimientoController();
  
  late List<Movimiento> listaMutable;

  @override
  void initState() {
    super.initState();
    listaMutable = List.from(widget.movimientos);
  }

  bool esDelMesActual(DateTime fecha) {
    DateTime now = DateTime.now();
    return fecha.month == now.month && fecha.year == now.year;
  }

  int? idUsuario = DatabaseHelper.instance.userId;
  List<Movimiento> movimientos = [];
  double balanceTotal = 0.0;

  Future<void> recargarDatos() async {
    if (idUsuario == null) return;
    final list = await _logic.obtenerMovimientos(idUsuario!);
    final balance = await _logic.formatearBalance(idUsuario!);
    setState(() {
      movimientos = list;
      balanceTotal = balance;
    });
  }

 void _borrarMovimiento(int index, int idBaseDatos) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¿Eliminar movimiento?"),
        content: const Text("Estás a punto de borrar este registro financiero. Esta acción alterará tu balance actual y no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            onPressed: () async {
              await _logic.borrarMovimiento(idBaseDatos);
              
              if (context.mounted) Navigator.pop(context);
              
              setState(() {
                listaMutable.removeAt(index);
              });
              recargarDatos();
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var listaMes = listaMutable.where((m) => esDelMesActual(m.fecha)).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Historial del Mes", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: listaMes.isEmpty
          ? const Center(child: Text("No hay movimientos este mes.", style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: listaMes.length,
              itemBuilder: (_, index) {
                var m = listaMes[index];
                bool esIngreso = m.tipo == "ingreso";

                String dia = m.fecha.day.toString().padLeft(2, '0');
                String mes = m.fecha.month.toString().padLeft(2, '0');
                String anio = m.fecha.year.toString();
                String fechaLimpia = "$dia/$mes/$anio";

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04), 
                        blurRadius: 10,
                        offset: const Offset(0, 5)
                      )
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    title: Text(
                      m.descripcion ?? "Sin descripción", 
                      style: TextStyle(fontWeight: FontWeight.bold)
                    ),
                    subtitle: Text(fechaLimpia),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "\$${(m.monto / 100).toStringAsFixed(2)}",
                          style: TextStyle(
                            color: esIngreso ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: AppColors.accent),
                          onPressed: () => _mostrarDialogoEdicion(m, index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () {
                            int originalIndex = listaMutable.indexOf(m);
                            _borrarMovimiento(originalIndex, m.id!);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
  
  void _mostrarDialogoEdicion(Movimiento m, int index) {
    TextEditingController mC = TextEditingController(text: (m.monto / 100).toStringAsFixed(2));
    TextEditingController dC = TextEditingController(text: m.descripcion);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Editar Movimiento"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: mC, 
              keyboardType: const TextInputType.numberWithOptions(decimal: true), 
              decoration: InputDecoration(labelText: "Nuevo Monto", border: OutlineInputBorder())
            ),
            const SizedBox(height: 15),
            TextField(
              controller: dC, 
              decoration: InputDecoration(labelText: "Nueva Descripción", border: OutlineInputBorder())
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            onPressed: () async {
              bool exito = await _logic.actualizarMovimiento(m.id!, mC.text, dC.text);
              
              if (exito) {
                setState(() {
                  double nuevoValor = double.parse(mC.text);
                  m.monto = (nuevoValor * 100).round();
                  m.descripcion = dC.text;
                  listaMutable[index] = m;
                  recargarDatos();
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Actualizar", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}

class IngresosEgresosScreenState extends State<IngresosEgresosScreen> {
  
  final MovimientoController _logic = MovimientoController();
  List<Movimiento> movimientos = [];
  double balanceTotal = 0.0;
  int? idUsuario = DatabaseHelper.instance.userId;
  
  final Color primaryBlue = Colors.blue;
  final Color secondaryGreen = Colors.green;
  final Color criticalRed = Colors.redAccent;
  final Color backgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();
    recargarDatos();
  }

  Future<void> recargarDatos() async {
    if (idUsuario == null) return;
    final list = await _logic.obtenerMovimientos(idUsuario!);
    final balance = await _logic.formatearBalance(idUsuario!);
    setState(() {
      movimientos = list;
      balanceTotal = balance;
    });
  }

  Future<void> _mostrarHistorial() async {
    await Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => HistorialScreen(movimientos))
    );
    recargarDatos(); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              _buildBalanceCard(),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(child: _buildSummaryCard("Ingresos", _calcularSuma("ingreso"), secondaryGreen, Icons.arrow_upward)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSummaryCard("Egresos", _calcularSuma("egreso"), criticalRed, Icons.arrow_downward)),
                ],
              ),

              const SizedBox(height: 32),

              _buildHealthSection(),

              const SizedBox(height: 40),

              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            blurRadius: 20,
            offset: const Offset(0, 10)
          )
        ],
      ),
      child: Column(
        children: [
          const Text("Balance General", style: TextStyle(color: Colors.black54, fontSize: 16)),
          const SizedBox(height: 10),
          Text(
            "\$${balanceTotal.toStringAsFixed(2)}", 
            style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.black87)
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            blurRadius: 10,
            offset: const Offset(0, 5)
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          
          const SizedBox(height: 12),
          
          Text(title, style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text("\$${amount.toStringAsFixed(2)}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildHealthSection() {
    double ratio = _calcularSuma("ingreso") == 0 ? 0 : (_calcularSuma("egreso") / _calcularSuma("ingreso"));
    
    Color color;
    String estadoSalud;
    String descripcionSalud;

    if (ratio > 0.8) {
      color = criticalRed;
      estadoSalud = "Crítico";
      descripcionSalud = "Tus gastos están al límite.";
    } else if (ratio > 0.5) {
      color = Colors.orange;
      estadoSalud = "Precaución";
      descripcionSaludo = "Modera tus egresos.";
    } else {
      color = secondaryGreen;
      estadoSalud = "Excelente";
      descripcionSalud = "Finanzas bajo control.";
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            blurRadius: 10,
            offset: const Offset(0, 5)
          )
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  strokeWidth: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                Center(
                  child: Text(
                    "${(ratio * 100).toStringAsFixed(0)}%",
                    style: TextStyle(
                      fontWeight: FontWeight.w900, 
                      fontSize: 18,
                      color: Colors.black87
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 24),
          
          Expanded( 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Salud: $estadoSalud", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)
                ),
                const SizedBox(height: 4),
                Text(
                  descripcionSalud, 
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14)
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  double _calcularSuma(String tipo) {
    int total = movimientos.where((m) => m.tipo == tipo).fold(0, (sum, m) => sum + m.monto);
    return total / 100.0;
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCircleButton(Icons.history, primaryBlue, _mostrarHistorial),
        const SizedBox(width: 20),
        _buildCircleButton(Icons.add, primaryBlue, _mostrarMenuAgregar),
      ],
    );
  }

  Widget _buildCircleButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: color, 
          shape: BoxShape.rectangle, 
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5)
            )
          ]
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  void _mostrarMenuAgregar() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: secondaryGreen, child: Icon(Icons.arrow_downward, color: primaryBlue)), 
              title: const Text("Registrar Ingreso", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)), 
              onTap: () => _abrirDialogo("ingreso")
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(backgroundColor: criticalRed, child: Icon(Icons.arrow_upward, color: primaryBlue)), 
              title: const Text("Registrar Egreso", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)), 
              onTap: () => _abrirDialogo("egreso")
            ),
          ],
        ),
      ),
    );
  }

  void _abrirDialogo(String tipo) {
    Navigator.pop(context);
    TextEditingController mC = TextEditingController();
    TextEditingController dC = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tipo == "ingreso" ? "Nuevo Ingreso" : "Nuevo Egreso", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: mC, 
              keyboardType: const TextInputType.numberWithOptions(decimal: true), 
              decoration: InputDecoration(labelText: "Monto (\$)", border: OutlineInputBorder())
            ),
            const SizedBox(height: 15),
            TextField(
              controller: dC, 
              decoration: InputDecoration(labelText: "Descripción", border: OutlineInputBorder())
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            onPressed: () async {
              await _logic.registrarMovimiento(
                montoRaw: mC.text, descripcion: dC.text, tipo: tipo, frecuencia: 'ninguna', usuarioId: idUsuario!,
              );
              await recargarDatos();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Guardar", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
