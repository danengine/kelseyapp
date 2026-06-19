import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/unit_listing.dart';

/// Fullscreen swipeable photo gallery for unit listings.
class UnitGalleryViewer extends StatefulWidget {
  const UnitGalleryViewer({
    super.key,
    required this.urls,
    this.initialIndex = 0,
    this.title,
  });

  final List<String> urls;
  final int initialIndex;
  final String? title;

  static Future<void> open(
    BuildContext context, {
    required List<String> urls,
    int initialIndex = 0,
    String? title,
  }) {
    if (urls.isEmpty) return Future.value();
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => UnitGalleryViewer(
          urls: urls,
          initialIndex: initialIndex.clamp(0, urls.length - 1),
          title: title,
        ),
      ),
    );
  }

  static Future<void> openForUnit(BuildContext context, UnitListing unit) async {
    final urls = await _loadUnitImageUrls(unit);
    if (!context.mounted || urls.isEmpty) return;
    await open(context, urls: urls, title: unit.title);
  }

  static Future<List<String>> _loadUnitImageUrls(UnitListing unit) async {
    if (unit.id.isEmpty) {
      return unit.mainImageUrl.isNotEmpty ? [unit.mainImageUrl] : const [];
    }
    try {
      final response = await http.get(Uri.parse(ApiConfig.unitUrl(unit.id))).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return unit.mainImageUrl.isNotEmpty ? [unit.mainImageUrl] : const [];
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final images = body['image_urls'];
      if (images is List && images.isNotEmpty) {
        return images
            .map((e) => ApiConfig.resolveMediaUrl(e.toString()))
            .where((url) => url.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return unit.mainImageUrl.isNotEmpty ? [unit.mainImageUrl] : const [];
  }

  @override
  State<UnitGalleryViewer> createState() => _UnitGalleryViewerState();
}

class _UnitGalleryViewerState extends State<UnitGalleryViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final urls = widget.urls;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    urls[i],
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: top + 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
                if (widget.title != null) ...[
                  Expanded(
                    child: Text(
                      widget.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ] else
                  const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_index + 1} / ${urls.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
