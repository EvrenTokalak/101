part of 'game.dart';

/// Crops only the requested decoration from the supplied scene reference.
class _SceneReferenceCrop extends StatelessWidget {
  final Rect region;
  const _SceneReferenceCrop({required this.region});

  @override
  Widget build(BuildContext context) => ClipRect(
    child: LayoutBuilder(
      builder: (context, bounds) => Stack(
        children: [
          Positioned(
            left: -region.left * bounds.maxWidth / region.width,
            top: -region.top * bounds.maxHeight / region.height,
            width: 1860 * bounds.maxWidth / region.width,
            height: 845 * bounds.maxHeight / region.height,
            child: Image.asset(
              'images/ui/icons/game-scene-reference.webp',
              fit: BoxFit.fill,
              cacheWidth: 1860,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Keep the reference's gold edges, with a live score/tile in the empty center.
class _SceneReferenceFrame extends StatelessWidget {
  final Rect region;
  final Widget child;
  const _SceneReferenceFrame({required this.region, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF183527), Color(0xFF080F0B)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
      ClipPath(
        clipper: const _SceneFrameEdges(7),
        child: _SceneReferenceCrop(region: region),
      ),
      Padding(padding: const EdgeInsets.all(3), child: child),
    ],
  );
}

class _SceneFrameEdges extends CustomClipper<Path> {
  final double radius;
  const _SceneFrameEdges(this.radius);
  @override
  Path getClip(Size size) {
    final border = min(size.width, size.height) * .085;
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(border),
          Radius.circular(max(1, radius - border)),
        ),
      );
  }

  @override
  bool shouldReclip(_SceneFrameEdges oldClipper) => oldClipper.radius != radius;
}
