import 'package:dm/data/database/database_helper.dart';
import 'package:dm/logic/movimiento_controller.dart';
import 'package:dm/logic/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

class TarjetasScreen extends StatefulWidget {
  const TarjetasScreen({super.key});

  @override
  State<TarjetasScreen> createState() => TarjetasScreenState();
}

class TarjetasScreenState extends State<TarjetasScreen> {
  double _presupuesto = 0.0;
  List<Map<String, dynamic>> _misTarjetas = [];
  String _nombreUsuario = "Cargando...";
  bool _cargando = true;
  double _porcentajeSalud = 0.0; 

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }
  
  Future<void> _programarAlertasTarjeta(String nombre, int diaCorte, int diaPago) async {
    DateTime ahora = DateTime.now();

    DateTime calcularFechaAlerta(int diaObjetivo) {
      DateTime fechaProgramada = DateTime(ahora.year, ahora.month, diaObjetivo, 9, 0);

      if (diaObjetivo == ahora.day) {
        if (ahora.hour >= 9) {
          return ahora.add(const Duration(minutes: 1));
        } else {
          return fechaProgramada;
        }
      } else if (fechaProgramada.isBefore(ahora)) {
        return DateTime(ahora.year, ahora.month + 1, diaObjetivo, 9, 0);
      }
      
      return fechaProgramada; 
    }

    DateTime fechaCorte = calcularFechaAlerta(diaCorte);
    try {
      await NotificationService().programarNotificacion(
        DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1, 
        "Día de Corte: $nombre",
        "Hoy cierra tu tarjeta. No olvides declarar el saldo en UniPocket.",
        fechaCorte
      );
    } catch (e) {
      debugPrint("Error alerta corte: $e");
    }

    DateTime fechaPago = calcularFechaAlerta(diaPago);
    try {
      await NotificationService().programarNotificacion(
        DateTime.now().millisecondsSinceEpoch ~/ 1000 + 2, 
        "Día de Pago: $nombre",
        "¡Último día de pago en $nombre! Evita cargos por intereses.",
        fechaPago
      );
    } catch (e) {
      debugPrint("Error alerta pago: $e");
    }
    
    debugPrint("Alertas programadas exitosamente para $nombre");
  }

  Future<void> pagarTarjeta(Map<String, dynamic> tarjeta, double montoAPagar) async {
    final db = await DatabaseHelper.instance.database;
    int? userId = DatabaseHelper.instance.userId;

    int balanceActualCentavos = await DatabaseHelper.instance.obtenerBalance(userId!);
    double balanceActualPesos = balanceActualCentavos / 100;
    
    if (montoAPagar > balanceActualPesos) {
      Fluttertoast.showToast(msg: "Fondos insuficientes", backgroundColor: Colors.red);
      return;
    }

    final logic = MovimientoController();
    await logic.registrarMovimiento(
      montoRaw: montoAPagar.toString(), 
      descripcion: "Pago de tarjeta: ${tarjeta['nombre_tarjeta']}",
      tipo: "egreso",
      frecuencia: "ninguna",
      usuarioId: userId,
    );

    await db.update('tarjeta', {'pagada': 1, 'ultimo_mes_pagado': DateTime.now().month}, where: 'id = ?', whereArgs: [tarjeta['id']]);
    Fluttertoast.showToast(msg: "Tarjeta pagada con éxito", backgroundColor: Colors.green);
    cargarDatos();
  }

  void _declararCorte(Map<String, dynamic> tarjeta) {
    TextEditingController deudaCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Estado de Cuenta: ${tarjeta['nombre_tarjeta']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Ingresa el 'Pago para no generar intereses' que marca la app de tu banco:", style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(
              controller: deudaCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: "Deuda Total", prefixText: "\$ ", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004481)),
            onPressed: () async {
              double deuda = double.tryParse(deudaCtrl.text) ?? 0;
              if (deuda > 0) {
                Navigator.pop(context);
                final db = await DatabaseHelper.instance.database;
                await db.update(
                  'tarjeta', 
                  {'monto_minimo': (deuda * 100).toInt()},
                  where: 'id = ?', 
                  whereArgs: [tarjeta['id']]
                );
                Fluttertoast.showToast(msg: "Deuda registrada. Presupuesto ajustado.");
                cargarDatos();
              }
            },
            child: const Text("Declarar", style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
  }

  void _mostrarDialogoPago(Map<String, dynamic> tarjeta) {
    double montoSugerido = (tarjeta['monto_minimo'] as num).toDouble() / 100;
    TextEditingController pagoCtrl = TextEditingController(text: montoSugerido.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Pagar ${tarjeta['nombre_tarjeta']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Confirma el monto que transferirás a tu tarjeta.", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(
              controller: pagoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: "Monto a pagar", prefixText: "\$ ", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004481)),
            onPressed: () {
              double montoReal = double.tryParse(pagoCtrl.text) ?? 0.0;
              if (montoReal > 0) {
                Navigator.pop(context);
                pagarTarjeta(tarjeta, montoReal);
              }
            },
            child: const Text("Confirmar Pago", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  int _calcularDiasRestantes(int diaObjetivo) {
    DateTime hoy = DateTime.now();
    DateTime fechaObjetivo = DateTime(hoy.year, hoy.month, diaObjetivo);
    if (hoy.day > diaObjetivo) {
      fechaObjetivo = DateTime(hoy.year, hoy.month + 1, diaObjetivo);
    }
    DateTime soloHoy = DateTime(hoy.year, hoy.month, hoy.day);
    return fechaObjetivo.difference(soloHoy).inDays;
  }

  Future<void> eliminarTarjeta(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('tarjeta', where: 'id = ?', whereArgs: [id]);
    Fluttertoast.showToast(msg: "Tarjeta eliminada");
    cargarDatos();
  }

  void _confirmarEliminacion(int id, String nombre) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar tarjeta?"),
        content: Text("Estás a punto de borrar la tarjeta $nombre. Esta acción no se puede deshacer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              eliminarTarjeta(id);
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> cargarDatos() async {
    setState(() => _cargando = true);
    
    try {
      DatabaseHelper db = DatabaseHelper.instance;
      final baseDatos = await db.database;

      List<Map<String, dynamic>> tarjList = await baseDatos.query('tarjeta', where: 'usuario_id = ?', whereArgs: [db.userId]);

      for (var t in tarjList) {
        if (t['pagada'] == 1 && t['ultimo_mes_pagado'] != DateTime.now().month) {
          await baseDatos.update(
            'tarjeta', 
            {'pagada': 0, 'monto_minimo': 0},
            where: 'id = ?', 
            whereArgs: [t['id']]
          );
        }
      }
      
      tarjList = await baseDatos.query('tarjeta', where: 'usuario_id = ?', whereArgs: [db.userId]);

      String nombreDinamico = "Usuario";
      List<Map<String, dynamic>> userList = await baseDatos.query('usuario', where: 'id = ?', whereArgs: [db.userId], limit: 1);
      if (userList.isNotEmpty) nombreDinamico = userList.first['nombre'] ?? "Usuario";

      int balanceActualCentavos = await db.obtenerBalance(db.userId!);
      double balancePesos = balanceActualCentavos / 100;

      final ingresosData = await baseDatos.rawQuery("SELECT SUM(monto) as total FROM movimiento WHERE tipo = 'ingreso' AND usuario_id = ?", [db.userId]);
      double ingresosPesos = ((ingresosData.first['total'] as num?)?.toDouble() ?? 0.0) / 100;

      double obligacionesTotales = 0.0;
      for(var t in tarjList) {
        if (t['pagada'] == 0 && t['monto_minimo'] != null) {
          obligacionesTotales += (t['monto_minimo'] as num).toDouble() / 100;
        }
      }
      
      double libreParaGastar = balancePesos - obligacionesTotales;
      if (libreParaGastar < 0) libreParaGastar = 0;
      
      DateTime hoy = DateTime.now();
      int diasRestantesMes = DateTime(hoy.year, hoy.month + 1, 0).day - hoy.day + 1;
      
      double presupuestoDiarioReal = libreParaGastar / diasRestantesMes;

      double porcentaje = 0.0;
      if (ingresosPesos > 0) {
         porcentaje = (ingresosPesos - obligacionesTotales) / ingresosPesos; 
         if (porcentaje < 0) porcentaje = 0;
      }

      setState(() {
        _presupuesto = presupuestoDiarioReal;
        _misTarjetas = tarjList;
        _porcentajeSalud = porcentaje;
        _nombreUsuario = nombreDinamico;
      });

    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => _cargando = false);
    }
  }

  void _mostrarFormularioNuevaTarjeta(BuildContext context) {
    final nombreCtrl = TextEditingController();
    final numeroCtrl = TextEditingController();
    final corteCtrl = TextEditingController();
    final pagoCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24, right: 24, top: 24
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Vincular Nueva Tarjeta", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF004481))),
                const SizedBox(height: 20),
                TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: "Banco (Ej. Nu, Rappi, BBVA)", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(controller: numeroCtrl, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: "Últimos 4 dígitos", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: TextField(controller: corteCtrl, maxLength: 2,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        if (newValue.text.isEmpty) return newValue;
                        int? valor = int.tryParse(newValue.text);
                        if (valor == null || valor > 31) return oldValue; 
                        return newValue;
                      }),
                    ],
                    keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Día de Corte", border: OutlineInputBorder()))),
                    
                    const SizedBox(width: 15),
                    Expanded(child: TextField(controller: pagoCtrl, maxLength: 2, 
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        if (newValue.text.isEmpty) return newValue;
                        int? valor = int.tryParse(newValue.text);
                        if (valor == null || valor > 31) return oldValue; 
                        return newValue;
                      }),
                    ],
                    keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Día de Pago", border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004481), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () async {
                      debugPrint("Tarjetita guardada");
                      int? idUsuario = DatabaseHelper.instance.userId;
                      if (idUsuario == null) return;

                      Map<String, dynamic> nuevaTarjeta = {
                        'usuario_id': idUsuario,
                        'nombre_tarjeta': nombreCtrl.text.isEmpty ? 'Desconocido' : nombreCtrl.text,
                        'numero_tarjeta': 'XXXX XXXX XXXX ${numeroCtrl.text}',
                        'tipo': 'Credito',
                        'corte_dia': int.tryParse(corteCtrl.text) ?? 1,
                        'pago_dia': int.tryParse(pagoCtrl.text) ?? 1,
                        'monto_minimo': 0,
                        'pagada': 0,
                        'ultimo_mes_pagado': 0
                      };

                      await DatabaseHelper.instance.insertarTarjeta(nuevaTarjeta);
                      await _programarAlertasTarjeta(nuevaTarjeta['nombre_tarjeta'], nuevaTarjeta['corte_dia'], nuevaTarjeta['pago_dia']);
                      if (context.mounted) Navigator.pop(context);
                      await cargarDatos(); 
                    },
                    child: const Text("Guardar Tarjeta", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    bool esNegativo = _presupuesto <= 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: _cargando 
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      children: [
                        Text("Hola $_nombreUsuario", style: const TextStyle(fontSize: 22, color: Colors.black87)),
                        const SizedBox(width: 5),
                        const Text("👋", style: TextStyle(fontSize: 22)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text("Hoy puedes gastar....", style: TextStyle(fontSize: 16, color: Colors.black54)),
                  ),
                  const SizedBox(height: 10),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                      ),
                      child: Column(
                        children: [
                          Text(
                            "\$${_presupuesto.toStringAsFixed(2)} MXN",
                            style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: esNegativo ? Colors.red : const Color(0xFF4CAF50)),
                          ),
                          const SizedBox(height: 10),
                          const Text("\"Sin afectar pagos ni metas\"", style: TextStyle(color: Colors.black45, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 35),

                  if (_misTarjetas.isNotEmpty) ...[
                    SizedBox(
                      height: 225, 
                      child: PageView.builder(
                        controller: PageController(viewportFraction: 0.88),
                        itemCount: _misTarjetas.length,
                        itemBuilder: (context, index) {
                          final t = _misTarjetas[index];
                          
                          bool estaPagada = t['pagada'] == 1;
                          bool enReposo = !estaPagada && (t['monto_minimo'] == 0 || t['monto_minimo'] == null);
                          bool conDeuda = !estaPagada && !enReposo;

                          int diasParaCorte = _calcularDiasRestantes(t['corte_dia'] ?? 1);
                          int diasParaPago = _calcularDiasRestantes(t['pago_dia'] ?? 1);

                          return Column(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    height: 185, width: double.infinity,
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      color: estaPagada ? Colors.grey.shade400 : (conDeuda ? const Color(0xFFD35400) : const Color(0xFF004481)),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t['nombre_tarjeta'] ?? "BANCO", 
                                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                        ),
                                        const Spacer(),
                                        Text(
                                          t['numero_tarjeta'] ?? "XXXX XXXX XXXX XXXX",
                                          style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _nombreUsuario.toUpperCase(),
                                          style: const TextStyle(color: Colors.white, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  Positioned(
                                    top: 5,
                                    right: 10,
                                    child: PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, color: Colors.white),
                                      onSelected: (val) {
                                        if (val == 'declarar') _declararCorte(t);
                                        if (val == 'pagar') _mostrarDialogoPago(t);
                                        if (val == 'borrar') _confirmarEliminacion(t['id'], t['nombre_tarjeta']);
                                      },
                                      itemBuilder: (context) => [
                                        if (enReposo) const PopupMenuItem(value: 'declarar', child: Text("Declarar Corte")),
                                        if (conDeuda) const PopupMenuItem(value: 'pagar', child: Text("Realizar Pago")),
                                        if (conDeuda) const PopupMenuItem(value: 'declarar', child: Text("Editar Deuda")),
                                        const PopupMenuItem(value: 'borrar', child: Text("Eliminar", style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  ),

                                  if (estaPagada)
                                    Positioned.fill(
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(20)),
                                        child: const Center(
                                          child: Text("PAGADA", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)),
                                        ),
                                      ),
                                    )
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (estaPagada)
                                const Text("\"Tarjeta al corriente este mes\"", style: TextStyle(color: Colors.green, fontStyle: FontStyle.italic, fontSize: 14))
                              else if (enReposo)
                                Text("\"Día de corte en $diasParaCorte días\"", style: const TextStyle(color: Color(0xFF004481), fontStyle: FontStyle.italic, fontSize: 14))
                              else if (conDeuda)
                                Text("⚠️ Pago de \$${(t['monto_minimo']/100).toStringAsFixed(2)} en $diasParaPago días", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Center(child: Text("👉 Desliza para ver tus otras tarjetas", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12))),
                  ] else ...[
                    const Center(child: Text("No tienes tarjetas registradas.\nPresiona el botón '+' para agregar una.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
                  ],

                  const SizedBox(height: 45),

                  Center(
                    child: Column(
                      children: [
                        SizedBox(
                          width: 200, height: 200,
                          child: Stack(
                            children: [
                              Center(
                                child: SizedBox(
                                  width: 200, height: 200,
                                  child: CircularProgressIndicator(
                                    value: _porcentajeSalud, 
                                    strokeWidth: 20, 
                                    backgroundColor: Colors.grey.shade300,
                                    valueColor: AlwaysStoppedAnimation<Color>(_porcentajeSalud < 0.20 ? Colors.red : const Color(0xFF4CAF50)),
                                  ),
                                ),
                              ),
                              Center(
                                child: Text(
                                  "${(_porcentajeSalud * 100).toInt()}%",
                                  style: const TextStyle(fontSize: 45, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text("Porcentaje de salud de deuda", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87))
                      ],
                    ),
                  ),
                  const SizedBox(height: 80), 
                ],
              ),
            ),
          ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF004481),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _mostrarFormularioNuevaTarjeta(context),
      ),
    );
  }
}