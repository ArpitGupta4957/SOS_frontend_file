import 'package:flutter/material.dart';

class OptionButton extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;
  const OptionButton(
      {required this.title,
      required this.color,
      required this.icon,
      required this.onPressed,
      super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
          backgroundColor: color, padding: const EdgeInsets.all(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 24),
          ),
        ],
      ),
    );
  }
}
