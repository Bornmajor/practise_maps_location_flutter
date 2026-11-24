import 'package:flutter/material.dart';
import 'package:practise_maps_location_flutter/presentations/location_fetch_screen.dart';
import 'package:practise_maps_location_flutter/presentations/background_map_screen.dart';
import 'package:practise_maps_location_flutter/presentations/states/location_state.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  final LocationState state = const LocationState();

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const BackgroundMapScreen()
    );
  }
}

