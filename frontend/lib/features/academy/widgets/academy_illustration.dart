import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../shared/ui/heritage_photo.dart';

enum AcademyDrawing {
  people,
  bulb,
  money,
  cycle,
  fish,
  microbes,
  plant,
  water,
  flag,
  tools,
  chart,
  checklist,
  listen,
  share,
  book,
  search,
}

/// Concept illustrations are drawn on canvas, independent of icon fonts.
class AcademyIllustration extends StatelessWidget {
  final String courseTitle;
  final String lessonTitle;
  const AcademyIllustration({
    super.key,
    required this.courseTitle,
    required this.lessonTitle,
  });
  @override
  Widget build(BuildContext context) {
    final key = '$courseTitle $lessonTitle'.toLowerCase();
    final photo =
        heritagePhotoFor(key) ??
        const HeritagePhotoData(
          'world-cup-2018-delegation',
          'Enactus ESP : apprendre ensemble et porter ses projets jusqu’à la compétition internationale.',
        );
    final steps = key.contains('aquatus') || key.contains('aquaponie')
        ? [
            ('Poissons', AcademyDrawing.fish),
            ('Bactéries', AcademyDrawing.microbes),
            ('Plantes', AcademyDrawing.plant),
            ('Eau en circulation', AcademyDrawing.water),
          ]
        : key.contains('économ') ||
              key.contains('coût') ||
              key.contains('business') ||
              key.contains('revenu')
        ? [
            ('Besoin social', AcademyDrawing.people),
            ('Offre utile', AcademyDrawing.bulb),
            ('Coûts et recettes', AcademyDrawing.money),
            ('Continuité', AcademyDrawing.cycle),
          ]
        : key.contains('impact') ||
              key.contains('résultat') ||
              key.contains('odd')
        ? [
            ('Situation de départ', AcademyDrawing.flag),
            ('Action', AcademyDrawing.tools),
            ('Changement observé', AcademyDrawing.chart),
            ('Mesure et limites', AcademyDrawing.checklist),
          ]
        : key.contains('équipe') ||
              key.contains('transm') ||
              key.contains('enactspace') ||
              key.contains('minute')
        ? [
            ('Écouter', AcademyDrawing.listen),
            ('Contribuer', AcademyDrawing.people),
            ('Partager', AcademyDrawing.share),
            ('Transmettre', AcademyDrawing.book),
          ]
        : [
            ('Comprendre', AcademyDrawing.search),
            ('Imaginer', AcademyDrawing.bulb),
            ('Essayer', AcademyDrawing.tools),
            ('Apprendre', AcademyDrawing.book),
          ];
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HeritagePhoto(photo: photo),
            const SizedBox(height: 20),
            Text(
              'Les idées en image',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final columns = constraints.maxWidth < 270 || scale > 1.8
                    ? 1
                    : constraints.maxWidth < 540 || scale > 1.3
                    ? 2
                    : 4;
                final itemWidth =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < steps.length; i++)
                      SizedBox(
                        width: itemWidth,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.secondaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Semantics(
                                image: true,
                                label: steps[i].$1,
                                child: SizedBox(
                                  width: 88,
                                  height: 70,
                                  child: CustomPaint(
                                    key: ValueKey(
                                      'academy-drawing-${steps[i].$2.name}',
                                    ),
                                    painter: AcademyConceptPainter(
                                      steps[i].$2,
                                      colors.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${i + 1}. ${steps[i].$1}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.onSecondaryContainer,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Relie ces repères à l’exemple de la leçon. Tu peux revenir à une étape lorsque tu apprends quelque chose de nouveau.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class AcademyConceptPainter extends CustomPainter {
  final AcademyDrawing drawing;
  final Color color;
  const AcademyConceptPainter(this.drawing, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 88, size.height / 70);
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    void line(double x, double y, double a, double b) =>
        canvas.drawLine(Offset(x, y), Offset(a, b), stroke);
    void circle(double x, double y, double r) {
      canvas.drawCircle(Offset(x, y), r, fill);
      canvas.drawCircle(Offset(x, y), r, stroke);
    }

    void box(double x, double y, double w, double h) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        const Radius.circular(5),
      );
      canvas.drawRRect(r, fill);
      canvas.drawRRect(r, stroke);
    }

    switch (drawing) {
      case AcademyDrawing.people:
        for (final x in [20.0, 44.0, 68.0]) {
          circle(x, 22, 7);
          canvas.drawArc(
            Rect.fromLTWH(x - 12, 35, 24, 28),
            math.pi,
            math.pi,
            false,
            stroke,
          );
          line(x - 12, 49, x + 12, 49);
        }
      case AcademyDrawing.bulb:
        circle(44, 27, 15);
        line(36, 41, 36, 51);
        line(52, 41, 52, 51);
        line(36, 51, 52, 51);
        line(39, 58, 49, 58);
        for (final a in [-math.pi, -math.pi / 2, 0.0]) {
          line(
            44 + 22 * math.cos(a),
            27 + 22 * math.sin(a),
            44 + 28 * math.cos(a),
            27 + 28 * math.sin(a),
          );
        }
      case AcademyDrawing.money:
        box(12, 18, 40, 28);
        circle(32, 32, 7);
        line(19, 25, 21, 25);
        line(43, 39, 45, 39);
        for (final y in [34.0, 43.0, 52.0]) {
          canvas.drawOval(Rect.fromLTWH(49, y, 26, 12), fill);
          canvas.drawOval(Rect.fromLTWH(49, y, 26, 12), stroke);
        }
      case AcademyDrawing.cycle:
        canvas.drawArc(
          const Rect.fromLTWH(20, 12, 48, 48),
          -math.pi / 2,
          2.4,
          false,
          stroke,
        );
        canvas.drawArc(
          const Rect.fromLTWH(20, 12, 48, 48),
          math.pi / 2,
          2.4,
          false,
          stroke,
        );
        line(64, 47, 67, 35);
        line(64, 47, 52, 45);
        line(24, 25, 21, 37);
        line(24, 25, 36, 27);
      case AcademyDrawing.fish:
        canvas.drawOval(const Rect.fromLTWH(19, 22, 43, 28), fill);
        canvas.drawOval(const Rect.fromLTWH(19, 22, 43, 28), stroke);
        final tail = Path()
          ..moveTo(62, 36)
          ..lineTo(77, 23)
          ..lineTo(77, 49)
          ..close();
        canvas.drawPath(tail, fill);
        canvas.drawPath(tail, stroke);
        circle(30, 32, 2);
        line(42, 23, 49, 15);
      case AcademyDrawing.microbes:
        for (final p in [
          const Offset(25, 25),
          const Offset(58, 42),
          const Offset(24, 53),
        ]) {
          circle(p.dx, p.dy, 8);
          line(p.dx - 10, p.dy - 8, p.dx - 14, p.dy - 12);
          line(p.dx + 10, p.dy + 7, p.dx + 14, p.dy + 11);
        }
        circle(63, 17, 3);
        circle(43, 49, 2);
      case AcademyDrawing.plant:
        line(44, 58, 44, 24);
        line(44, 40, 29, 29);
        line(44, 32, 59, 21);
        canvas.drawOval(const Rect.fromLTWH(17, 18, 22, 15), fill);
        canvas.drawOval(const Rect.fromLTWH(17, 18, 22, 15), stroke);
        canvas.drawOval(const Rect.fromLTWH(49, 12, 23, 15), fill);
        canvas.drawOval(const Rect.fromLTWH(49, 12, 23, 15), stroke);
        line(25, 59, 64, 59);
      case AcademyDrawing.water:
        final p = Path()
          ..moveTo(44, 10)
          ..cubicTo(38, 22, 25, 32, 25, 43)
          ..cubicTo(25, 66, 63, 66, 63, 43)
          ..cubicTo(63, 32, 50, 22, 44, 10)
          ..close();
        canvas.drawPath(p, fill);
        canvas.drawPath(p, stroke);
        canvas.drawArc(
          const Rect.fromLTWH(34, 34, 21, 20),
          0,
          1.6,
          false,
          stroke,
        );
      case AcademyDrawing.flag:
        line(27, 60, 27, 10);
        final p = Path()
          ..moveTo(27, 13)
          ..lineTo(65, 13)
          ..lineTo(56, 24)
          ..lineTo(65, 35)
          ..lineTo(27, 35)
          ..close();
        canvas.drawPath(p, fill);
        canvas.drawPath(p, stroke);
        line(17, 60, 39, 60);
      case AcademyDrawing.tools:
        line(24, 55, 61, 18);
        line(24, 22, 61, 55);
        box(13, 15, 25, 13);
        circle(64, 14, 7);
        circle(20, 59, 4);
      case AcademyDrawing.chart:
        line(15, 12, 15, 58);
        line(15, 58, 75, 58);
        box(23, 39, 10, 19);
        box(41, 28, 10, 30);
        box(59, 17, 10, 41);
        line(23, 25, 57, 9);
        line(57, 9, 49, 9);
      case AcademyDrawing.checklist:
        box(19, 11, 50, 49);
        for (final y in [22.0, 36.0, 50.0]) {
          line(26, y, 29, y + 3);
          line(29, y + 3, 34, y - 4);
          line(42, y, 60, y);
        }
      case AcademyDrawing.listen:
        canvas.drawArc(
          const Rect.fromLTWH(34, 11, 25, 36),
          -math.pi,
          4.7,
          false,
          stroke,
        );
        canvas.drawArc(
          const Rect.fromLTWH(41, 20, 12, 17),
          -math.pi,
          3.5,
          false,
          stroke,
        );
        line(43, 40, 37, 52);
        circle(36, 55, 4);
        canvas.drawArc(
          const Rect.fromLTWH(15, 22, 15, 25),
          -1,
          2,
          false,
          stroke,
        );
        canvas.drawArc(
          const Rect.fromLTWH(6, 15, 24, 38),
          -1,
          2,
          false,
          stroke,
        );
      case AcademyDrawing.share:
        box(14, 12, 38, 28);
        line(21, 40, 21, 48);
        line(21, 48, 31, 40);
        box(40, 36, 34, 23);
        line(67, 59, 67, 64);
        line(60, 59, 67, 64);
      case AcademyDrawing.book:
        final p = Path()
          ..moveTo(44, 18)
          ..quadraticBezierTo(26, 8, 13, 16)
          ..lineTo(13, 53)
          ..quadraticBezierTo(27, 46, 44, 56)
          ..quadraticBezierTo(60, 46, 75, 53)
          ..lineTo(75, 16)
          ..quadraticBezierTo(62, 8, 44, 18)
          ..close();
        canvas.drawPath(p, fill);
        canvas.drawPath(p, stroke);
        line(44, 18, 44, 56);
        line(22, 27, 34, 29);
        line(53, 29, 66, 26);
        line(22, 36, 34, 38);
      case AcademyDrawing.search:
        circle(36, 29, 18);
        line(49, 43, 68, 61);
        line(32, 23, 40, 23);
        line(28, 31, 43, 31);
        line(31, 38, 39, 38);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AcademyConceptPainter oldDelegate) =>
      oldDelegate.drawing != drawing || oldDelegate.color != color;
}
