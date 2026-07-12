  import 'package:flutter/foundation.dart';
  import 'package:flutter_local_notifications/flutter_local_notifications.dart';
  import 'package:flutter_timezone/flutter_timezone.dart';
  import 'package:timezone/data/latest_all.dart' as tz;
  import 'package:timezone/timezone.dart' as tz;

  class NotificationService{
    static final NotificationService _instance = NotificationService._internal();
    factory NotificationService() => _instance;

    NotificationService._internal();

    final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
    
    Future<void> init() async{
      tz.initializeTimeZones();

      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

      const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(android: androidInit);

      await _plugin.initialize(settings: initSettings);

      const AndroidNotificationChannel canal = AndroidNotificationChannel(
        'canal_UniPocket',
        'Recordatorios',
        description: 'Notificaciones importantes',
        importance: Importance.max,
      );

      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(canal);
    }

    Future<void> requestPermission() async {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission(); 
      
      await Future.delayed(const Duration(seconds: 1));

      debugPrint("DEBUG: Forzando solicitud de alarma exacta...");
      try {
        await androidImplementation?.requestExactAlarmsPermission();
      } catch (e) {
        debugPrint("DEBUG: El permiso ya está concedido o hubo un salto en el plugin: $e");
      }
    }

    Future<void> programarNotificacion(int id, String titulo, String cuerpo, DateTime fechaVencimiento) async {
      final scheduleDate = tz.TZDateTime.from(fechaVencimiento, tz.local);

      debugPrint("DEBUG: Programando para (UTC): $scheduleDate");
      debugPrint("DEBUG: Tiempo actual (UTC): ${tz.TZDateTime.now(tz.local)}");

      await _plugin.zonedSchedule(
        id: id,
        title: titulo,
        body: cuerpo,
        scheduledDate: scheduleDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'canal_UniPocket',
            'Recordatorios',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint("Mensaje recibido"); // Hasta este punto la notificación sigue viva
    }

    Future<void> Bypass() async{
        debugPrint("Bypass al NotificationManager");
        await _plugin.show(
          id: 777,
          title: "Prueba de renderizado",
          body: "Revisión del renderizado en proceso",
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails('canal_UniPocket', 
            'Recordatorios',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher'),
          ),
        );
    }
  }