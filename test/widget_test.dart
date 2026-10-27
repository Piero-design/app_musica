import 'package:flutter_test/flutter_test.dart';

import 'package:app_musica/main.dart';

void main() {
  testWidgets('AppleMusicApp with DJ Mix and AI Radio Host test', (WidgetTester tester) async {
    // Construir la app
    await tester.pumpWidget(const AppleMusicApp());

    // Verificar las 5 pestañas principales
    expect(find.text('Escuchar'), findsWidgets);
    expect(find.text('DJ Mix'), findsWidgets);
    expect(find.text('Radio IA'), findsWidgets);
    expect(find.text('Biblioteca'), findsWidgets);
    expect(find.text('Buscar'), findsWidgets);

    // Navegar a la pestaña DJ Mix Studio
    await tester.tap(find.text('DJ Mix'));
    await tester.pump();

    expect(find.text('DJ Mix Studio'), findsOneWidget);
    expect(find.text('Reproducir Secuencia DJ Mix'), findsOneWidget);

    // Navegar a la pestaña Radio IA & Locutor
    await tester.tap(find.text('Radio IA'));
    await tester.pump();

    expect(find.text('Radio IA & Locutor'), findsOneWidget);
    expect(find.text('Locutor Virtual Inteligente'), findsOneWidget);
    expect(find.text('Ingeniería de Sistemas y Tech'), findsOneWidget);

    // Probar disparar la intervención del Locutor IA
    await tester.tap(find.text('Probar intervención del Locutor ahora'));
    await tester.pump();

    expect(find.text('Locutor IA al aire • Cápsula para Ing. de Sistemas'), findsOneWidget);

    // Avanzar el tiempo para que el timer del locutor concluya limpiamente
    await tester.pump(const Duration(seconds: 5));
  });
}
