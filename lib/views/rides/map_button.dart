import 'package:flutter/material.dart';


class RoundMapButton extends StatelessWidget {
   final IconData icon;
  final Color background;
  final Color iconColor;
  final VoidCallback onTap;
  const RoundMapButton({super.key, 
    required this.icon,
    required this.background,
    required this.iconColor,
    required this.onTap,
  });

 

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      surfaceTintColor: Colors.transparent,
      shape: const CircleBorder(),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        // customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}