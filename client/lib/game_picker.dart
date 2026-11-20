import 'package:flutter/material.dart';

class GamePicker extends StatelessWidget {
  const GamePicker({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Choose a game to create',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          ChoiceChip(
            avatar: const Icon(Icons.quiz_outlined, size: 20),
            label: const Text('Quiz · 1–10 players'),
            selected: value == 'quiz',
            onSelected: enabled ? (_) => onChanged('quiz') : null,
          ),
          ChoiceChip(
            avatar: const Icon(Icons.style_outlined, size: 20),
            label: const Text('KIKIK · 3–12 players'),
            selected: value == 'kikik',
            onSelected: enabled ? (_) => onChanged('kikik') : null,
          ),
          ChoiceChip(
            avatar: const Icon(Icons.visibility_off_outlined, size: 20),
            label: const Text('Butbutay · 3–6 players'),
            selected: value == 'butbutay',
            onSelected: enabled ? (_) => onChanged('butbutay') : null,
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        value == 'butbutay'
            ? 'Drop cards face down, declare a rank, and call LIE when you doubt a claim.'
            : value == 'kikik'
            ? 'Pass cards, collect four matching ranks, then call KIKIK first.'
            : 'Buzz first and answer English or math questions.',
        style: const TextStyle(fontSize: 14, height: 1.5),
      ),
    ],
  );
}
