import 'package:flutter/material.dart';

class StatusFilterChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const StatusFilterChip({
    super.key,
    required this.label,
    required this.value,
    required this.selected,
    this.color = Colors.grey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: color.withOpacity(0.2),
        checkmarkColor: color,
        labelStyle: TextStyle(
          color: selected ? color : Colors.black87,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        side: selected ? BorderSide(color: color) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
