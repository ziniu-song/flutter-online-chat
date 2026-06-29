import 'package:flutter/material.dart';

class UserCard extends StatelessWidget {
  const UserCard({
    super.key,
    required this.name,
    required this.bio,
    required this.interests,
    this.avatar,
    this.age = 22,
  });

  final String name;
  final String bio;
  final List<dynamic> interests;
  final String? avatar;
  final int age;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Stack(
          children: [
            Positioned.fill(child: _buildAvatar()),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.72),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 22,
              right: 22,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.favorite, color: Colors.pink, size: 16),
                    SizedBox(width: 5),
                    Text(
                      '附近的人',
                      style: TextStyle(
                        color: Colors.pink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 26,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name, $age',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    bio,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      height: 1.4,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: interests.map((item) {
                      return Chip(
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        label: Text(
                          item.toString(),
                          style: const TextStyle(color: Colors.pink),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final imageUrl = avatar;
    if (imageUrl == null || imageUrl.isEmpty) {
      return _fallbackAvatar();
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, error, stackTrace) => _fallbackAvatar(),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: Colors.pink.shade100,
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 90,
      ),
    );
  }
}
