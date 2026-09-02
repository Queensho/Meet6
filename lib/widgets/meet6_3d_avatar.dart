import 'package:flutter/material.dart';

class Meet63DAvatar extends StatelessWidget {
  const Meet63DAvatar({
    super.key,
    required this.alignment,
    required this.size,
    this.borderWidth = 3,
  });

  final Alignment alignment;
  final double size;
  final double borderWidth;

  static const assetPath =
      'assets/images/file_000000009c248210b0e425b8f2d3e68d.png';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 13,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipOval(
        child: SizedBox.expand(
          child: Transform.scale(
            scale: 3.25,
            alignment: alignment,
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              alignment: alignment,
            ),
          ),
        ),
      ),
    );
  }
}
