import 'package:flutter/material.dart';
import '../models/project_presentation.dart';
import '../../features/archives/screens/archive_visuals.dart';

class ProjectPhotoGallery extends StatelessWidget {
  final List<ProjectPhoto> photos;
  const ProjectPhotoGallery({super.key, required this.photos});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ResponsiveArchiveGrid(
        children: [
          for (final photo in photos)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HeritageImage(asset: photo.asset, title: photo.caption),
                    const SizedBox(height: 10),
                    Text(
                      photo.caption,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      if (photos.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Source : Photothèque Enactus ESP',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ],
  );
}
