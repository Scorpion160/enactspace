import 'package:flutter/material.dart';

class EnactBrandLockup extends StatelessWidget {
  final bool translucent;
  const EnactBrandLockup({super.key, this.translucent = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: translucent ? const Color(0xBFFFFFFF) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x33FFFFFF)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 360.0;
        final large = available >= 320;
        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 20,
          runSpacing: 16,
          children: [
            Image.asset(
              'assets/brand/logo/enactspace_logo_full_transparent.png',
              width: large ? 190 : 140,
              height: large ? 150 : 110,
              fit: BoxFit.contain,
              semanticLabel: 'EnactSpace',
            ),
            Semantics(
              label: 'Enactus ESP',
              image: true,
              child: SizedBox(
                width: large ? 150 : 130,
                height: large ? 150 : 130,
                child: const _IntegratedAssociationLogo(),
              ),
            ),
          ],
        );
      },
    ),
  );
}

// Multiply makes the source's white neutral against the shared panel.
// It retains the original logo artwork and lettering without regenerating it.
class _IntegratedAssociationLogo extends StatefulWidget {
  const _IntegratedAssociationLogo();
  @override
  State<_IntegratedAssociationLogo> createState() =>
      _IntegratedAssociationLogoState();
}

class _IntegratedAssociationLogoState
    extends State<_IntegratedAssociationLogo> {
  ImageStream? _stream;
  ImageInfo? _image;
  late final ImageStreamListener _listener = ImageStreamListener((
    image,
    synchronousCall,
  ) {
    if (!mounted) {
      image.dispose();
      return;
    }
    final previous = _image;
    setState(() => _image = image);
    previous?.dispose();
  });
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = const AssetImage(
      'assets/img/logo_enactus_esp.png',
    ).resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) {
      return;
    }
    _stream?.removeListener(_listener);
    _stream = stream;
    stream.addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _AssociationPainter(_image));
}

class _AssociationPainter extends CustomPainter {
  final ImageInfo? image;
  _AssociationPainter(this.image);
  @override
  void paint(Canvas canvas, Size size) {
    final info = image;
    if (info == null) {
      return;
    }
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: info.image,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      blendMode: BlendMode.multiply,
    );
  }

  @override
  bool shouldRepaint(_AssociationPainter oldDelegate) =>
      oldDelegate.image != image;
}
