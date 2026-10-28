import 'package:flutter/material.dart'; 
void main() { 
  runApp(const MiAplicacion()); 
} 
class MiAplicacion extends StatelessWidget { 
  const MiAplicacion({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Práctica GUI Flutter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),    
      //Aquí iremos cambiando la pantalla activa según cada tema
      home: const PantallaPrueba(),

    );
  }
}
// Pantalla provisional 
class PantallaPrueba extends StatelessWidget { 
  const PantallaPrueba({super.key}); 
   @override 
  Widget build(BuildContext context) { 
    return const Scaffold( 
      body: Center( 
        child: Text('Proyecto Configurado Correctamente'), 
      ), 
    ); 
  } 
}