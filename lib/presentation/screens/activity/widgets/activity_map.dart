import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/activity.dart';

/// OpenStreetMap view for a GPS route.
///
/// In [live] mode the camera follows [current] as new points arrive; otherwise
/// the whole route is fitted into view once.
class ActivityMap extends StatefulWidget {
  const ActivityMap({
    super.key,
    required this.route,
    this.current,
    this.live = false,
  });

  final List<ActivityPoint> route;
  final ActivityPoint? current;
  final bool live;

  @override
  State<ActivityMap> createState() => _ActivityMapState();
}

class _ActivityMapState extends State<ActivityMap> {
  static const LatLng _fallbackCenter = LatLng(23.8103, 90.4125);

  final MapController _controller = MapController();
  bool _ready = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ActivityMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.live || !_ready) return;
    final ActivityPoint? point = widget.current;
    if (point == null) return;
    final ActivityPoint? previous = oldWidget.current;
    final bool moved =
        previous == null ||
        previous.latitude != point.latitude ||
        previous.longitude != point.longitude;
    if (!moved) return;
    _controller.move(
      LatLng(point.latitude, point.longitude),
      _controller.camera.zoom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<LatLng> points = widget.route
        .map((ActivityPoint point) => LatLng(point.latitude, point.longitude))
        .toList();
    final ActivityPoint? current =
        widget.current ?? (widget.route.isEmpty ? null : widget.route.last);
    final bool fitsRoute = !widget.live && points.length > 1;

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: points.isEmpty ? _fallbackCenter : points.first,
        initialZoom: 16,
        minZoom: 3,
        maxZoom: 19,
        initialCameraFit: fitsRoute
            ? CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(points),
                padding: const EdgeInsets.all(32),
              )
            : null,
        onMapReady: () {
          _ready = true;
          if (widget.live && current != null) {
            _controller.move(
              LatLng(current.latitude, current.longitude),
              _controller.camera.zoom,
            );
          }
        },
      ),
      children: <Widget>[
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.nexfit.app',
          maxZoom: 19,
        ),
        if (points.length > 1)
          PolylineLayer(
            polylines: <Polyline>[
              Polyline(
                points: points,
                strokeWidth: 5,
                color: context.colorScheme.primary,
                borderStrokeWidth: 2,
                borderColor: Colors.white,
              ),
            ],
          ),
        if (points.isNotEmpty)
          MarkerLayer(
            markers: <Marker>[
              if (points.length > 1)
                Marker(
                  point: points.first,
                  width: 18,
                  height: 18,
                  child: _RouteDot(color: AppColors.light.success),
                ),
              if (current != null)
                Marker(
                  point: LatLng(current.latitude, current.longitude),
                  width: 22,
                  height: 22,
                  child: _RouteDot(
                    color: context.colorScheme.primary,
                    ringColor: Colors.white,
                  ),
                ),
            ],
          ),
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: <SourceAttribution>[
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }
}

class _RouteDot extends StatelessWidget {
  const _RouteDot({required this.color, this.ringColor});

  final Color color;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: ringColor ?? Colors.white, width: 3),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x33000000), blurRadius: 6),
        ],
      ),
    );
  }
}
