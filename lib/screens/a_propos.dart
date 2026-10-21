import 'package:flutter/material.dart';

const versionAppli = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
const dateCompilation = String.fromEnvironment('BUILD_DATE', defaultValue: 'inconnue');

class AProposEcran extends StatelessWidget {
  const AProposEcran({super.key});

  @override
  Widget build(BuildContext context) {
    final gris = TextStyle(color: Theme.of(context).hintColor);
    Widget ligne(String a, String b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(child: Text(a, style: gris)),
              Expanded(child: Text(b)),
            ],
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('À propos')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(Icons.music_note,
                  size: 48, color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('TroDañs', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          ),
          Center(child: Text('Gestion des cours de danses bretonnes', style: gris)),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ligne('Version', versionAppli),
                  ligne('Compilée le', dateCompilation),
                  ligne('Conception', 'André Rodach'),
                  ligne('Développement', 'Claude (Anthropic)'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
