import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';

class AlumniAvatar extends StatelessWidget {
  const AlumniAvatar({
    super.key,
    required this.name,
    required this.photoUrl,
    required this.radius,
  });

  final String name;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rawPhoto = photoUrl?.trim() ?? '';
    final photo = rawPhoto.isEmpty ? null : Uri.tryParse(rawPhoto);
    final url = photo == null
        ? null
        : Uri.parse(ApiClient.serverUrl).resolveUri(photo);
    final image = url != null && (url.scheme == 'http' || url.scheme == 'https')
        ? NetworkImage(url.toString())
        : null;
    final fullName = name.trim();
    final parts = fullName.isEmpty
        ? <String>[]
        : fullName.split(RegExp(r'\s+'));
    final initials = switch (parts) {
      [] => '?',
      [final only] => only.characters.first.toUpperCase(),
      [final first, ..., final last] =>
        '${first.characters.first}${last.characters.first}'.toUpperCase(),
    };
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.secondaryContainer,
      foregroundColor: colors.onSecondaryContainer,
      foregroundImage: image,
      onForegroundImageError: image == null ? null : (_, _) {},
      child: Text(initials),
    );
  }
}
