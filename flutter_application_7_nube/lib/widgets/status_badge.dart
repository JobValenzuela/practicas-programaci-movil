import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String text;
  final bool good;
  const StatusBadge(this.text, {super.key, this.good = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: good ? const Color(0xffe0f5ed) : const Color(0xfffff0cf),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: good ? const Color(0xff14664c) : const Color(0xff805b12),
      ),
    ),
  );
}
