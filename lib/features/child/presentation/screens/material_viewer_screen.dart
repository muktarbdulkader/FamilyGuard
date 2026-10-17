import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/models/educational_material_model.dart';
import '../../../../core/services/education_service.dart';

class MaterialViewerScreen extends ConsumerStatefulWidget {
  final EducationalMaterial material;
  final String familyId;
  final String childId;
  final String childName;

  const MaterialViewerScreen({
    super.key,
    required this.material,
    required this.familyId,
    required this.childId,
    required this.childName,
  });

  @override
  ConsumerState<MaterialViewerScreen> createState() => _MaterialViewerScreenState();
}

class _MaterialViewerScreenState extends ConsumerState<MaterialViewerScreen> {
  VideoPlayerController? _videoController;
  late final WebViewController _webViewController;
  bool _isVideoInitialized = false;
  bool _useWebView = false;
  bool _isWebViewLoading = false;
  bool _isSavingProgress = false;
  late LearningStatus _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.material.statusFor(widget.childId);

    // Initialize webview controller
    _initWebViewController();

    // Mark as in-progress on first open if pending
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAsViewed();
    });

    final url = widget.material.effectiveUrl;
    final isVideo = widget.material.type == EduFileType.video;
    final isUrl = widget.material.type == EduFileType.url;

    if (isVideo && url.isNotEmpty) {
      if (_isWebVideo(url)) {
        // Direct web video (YouTube, Vimeo, etc.) -> load in-app WebView
        _loadInAppWebView(url);
      } else {
        // Direct media stream / storage file -> try native VideoPlayer first
        _initializeNativeVideo(url);
      }
    } else if (isUrl && url.isNotEmpty) {
      // Educational URL -> render directly in-app
      _loadInAppWebView(url);
    }
  }

  void _initWebViewController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isWebViewLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isWebViewLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
            if (mounted) setState(() => _isWebViewLoading = false);
          },
        ),
      );
  }

  bool _isWebVideo(String url) {
    final lower = url.toLowerCase();
    return lower.contains('youtube.com') ||
        lower.contains('youtu.be') ||
        lower.contains('vimeo.com') ||
        lower.contains('dailymotion.com') ||
        lower.contains('twitch.tv') ||
        lower.contains('khanacademy.org') ||
        lower.contains('coursera.org') ||
        lower.contains('ted.com');
  }

  String? _extractYouTubeId(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtube.com')) {
        if (uri.queryParameters.containsKey('v')) {
          return uri.queryParameters['v'];
        }
        if (uri.pathSegments.contains('embed')) {
          return uri.pathSegments.last;
        }
        if (uri.pathSegments.contains('shorts')) {
          return uri.pathSegments.last;
        }
      } else if (uri.host.contains('youtu.be')) {
        if (uri.pathSegments.isNotEmpty) {
          return uri.pathSegments.first;
        }
      }
    } catch (_) {}
    return null;
  }

  String? _extractVimeoId(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('vimeo.com')) {
        for (final segment in uri.pathSegments) {
          if (int.tryParse(segment) != null) {
            return segment;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  String _buildYouTubeHtml(String videoId) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { box-sizing: border-box; }
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      background-color: #000;
      overflow: hidden;
    }
    .video-container {
      position: relative;
      width: 100%;
      height: 100%;
    }
    iframe {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      border: 0;
    }
  </style>
</head>
<body>
  <div class="video-container">
    <iframe
      src="https://www.youtube-nocookie.com/embed/$videoId?autoplay=1&playsinline=1&rel=0&modestbranding=1"
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
      allowfullscreen>
    </iframe>
  </div>
</body>
</html>
''';
  }

  String _buildVimeoHtml(String videoId) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: #000; overflow: hidden; }
    iframe { width: 100%; height: 100%; border: 0; }
  </style>
</head>
<body>
  <iframe src="https://player.vimeo.com/video/$videoId?autoplay=1" allow="autoplay; fullscreen; picture-in-picture" allowfullscreen></iframe>
</body>
</html>
''';
  }

  void _loadInAppWebView(String url) {
    final youtubeId = _extractYouTubeId(url);
    final vimeoId = _extractVimeoId(url);

    setState(() {
      _useWebView = true;
      _isWebViewLoading = true;
    });

    if (youtubeId != null) {
      _webViewController.loadHtmlString(_buildYouTubeHtml(youtubeId));
    } else if (vimeoId != null) {
      _webViewController.loadHtmlString(_buildVimeoHtml(vimeoId));
    } else {
      _webViewController.loadRequest(Uri.parse(url));
    }
  }

  Future<void> _initializeNativeVideo(String url) async {
    try {
      final uri = Uri.parse(url);
      _videoController = VideoPlayerController.networkUrl(uri);
      await _videoController!.initialize();
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Native video player failed ($e). Falling back to in-app WebView player.');
      if (mounted) {
        // Seamless fallback to in-app webview player instead of showing an error
        _loadInAppWebView(url);
      }
    }
  }

  Future<void> _markAsViewed() async {
    if (_currentStatus == LearningStatus.pending) {
      await ref.read(educationServiceProvider).updateChildProgress(
            familyId: widget.familyId,
            materialId: widget.material.id,
            childId: widget.childId,
            childName: widget.childName,
            status: LearningStatus.inProgress,
          );
      if (mounted) {
        setState(() {
          _currentStatus = LearningStatus.inProgress;
        });
      }
    } else {
      await ref.read(educationServiceProvider).updateChildProgress(
            familyId: widget.familyId,
            materialId: widget.material.id,
            childId: widget.childId,
            childName: widget.childName,
            status: _currentStatus,
          );
    }
  }

  Future<void> _toggleCompletion() async {
    setState(() => _isSavingProgress = true);
    final nextStatus = _currentStatus == LearningStatus.completed
        ? LearningStatus.inProgress
        : LearningStatus.completed;

    try {
      await ref.read(educationServiceProvider).updateChildProgress(
            familyId: widget.familyId,
            materialId: widget.material.id,
            childId: widget.childId,
            childName: widget.childName,
            status: nextStatus,
          );

      if (mounted) {
        setState(() {
          _currentStatus = nextStatus;
          _isSavingProgress = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: nextStatus == LearningStatus.completed ? Colors.green : Colors.blue,
            content: Text(
              nextStatus == LearningStatus.completed
                  ? '🎉 Great job! Lesson marked as completed.'
                  : 'Lesson marked as in progress.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  Future<void> _launchExternalUrl() async {
    final url = widget.material.effectiveUrl;
    if (url.isEmpty) return;

    try {
      final uri = Uri.parse(url);
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open external link')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching link: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final material = widget.material;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          material.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in Browser/External App',
            onPressed: _launchExternalUrl,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Status',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          _currentStatus == LearningStatus.completed
                              ? Icons.check_circle
                              : (_currentStatus == LearningStatus.inProgress
                                  ? Icons.timelapse
                                  : Icons.radio_button_unchecked),
                          size: 16,
                          color: _statusColor(_currentStatus),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _currentStatus.label,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _statusColor(_currentStatus),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _isSavingProgress ? null : _toggleCompletion,
                style: FilledButton.styleFrom(
                  backgroundColor: _currentStatus == LearningStatus.completed
                      ? Colors.orange
                      : Colors.green,
                ),
                icon: _isSavingProgress
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        _currentStatus == LearningStatus.completed
                            ? Icons.replay
                            : Icons.check,
                      ),
                label: Text(
                  _currentStatus == LearningStatus.completed
                      ? 'Reopen Lesson'
                      : 'Mark as Completed',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media View Section (Native Video, In-App WebView Player, or Image)
            _buildMediaViewer(theme),

            // Content & Metadata
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          material.subject,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          material.gradeLevel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          material.type.badgeLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Title
                  Text(
                    material.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Due Date Alert if present
                  if (material.dueDate != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: material.isOverdue
                            ? Colors.red.withOpacity(0.12)
                            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 18,
                            color: material.isOverdue ? Colors.red : theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            material.isOverdue
                                ? 'Due on ${DateFormat('MMM d, yyyy').format(material.dueDate!)} (Overdue)'
                                : 'Due by ${DateFormat('MMM d, yyyy').format(material.dueDate!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: material.isOverdue ? Colors.red : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Learning Instructions (from parent)
                  if (material.instructions != null && material.instructions!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Parent's Instructions",
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            material.instructions!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Description
                  if (material.description.isNotEmpty) ...[
                    Text(
                      'About this lesson',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      material.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // External Link or Full Screen Button for Docs & PDFs
                  if (material.type != EduFileType.video && material.type != EduFileType.image && !_useWebView)
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _iconForType(material.type),
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    material.fileName ?? material.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tap below to read/open document',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaViewer(ThemeData theme) {
    final material = widget.material;

    // 1. In-App WebView Player (YouTube, Vimeo, Web Video, or educational URL)
    if (_useWebView) {
      return Container(
        height: 240,
        width: double.infinity,
        color: Colors.black,
        child: Stack(
          children: [
            WebViewWidget(controller: _webViewController),
            if (_isWebViewLoading)
              Container(
                color: Colors.black,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 10),
                      Text(
                        'Loading in-app player...',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // 2. Native Video Player (for direct MP4 / Storage video stream)
    if (material.type == EduFileType.video) {
      if (!_isVideoInitialized) {
        return Container(
          height: 220,
          color: Colors.black,
          alignment: Alignment.center,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 12),
              Text('Loading educational video...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        );
      }

      return Container(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio > 0
              ? _videoController!.value.aspectRatio
              : 16 / 9,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              VideoPlayer(_videoController!),
              // Controls overlay
              _VideoControlsOverlay(controller: _videoController!),
              VideoProgressIndicator(
                _videoController!,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: 2),
                colors: VideoProgressColors(
                  playedColor: theme.colorScheme.primary,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Image Viewer with Zoom & Pan
    if (material.type == EduFileType.image && material.effectiveUrl.isNotEmpty) {
      return Container(
        height: 280,
        width: double.infinity,
        color: Colors.black,
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: Image.network(
            material.effectiveUrl,
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (ctx, err, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image, size: 48, color: Colors.white54),
                  const SizedBox(height: 8),
                  const Text('Failed to load image', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 4. Document / PDF / Presentation Header Banner
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.7),
            theme.colorScheme.tertiaryContainer.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              _iconForType(material.type),
              size: 44,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            material.type.badgeLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _launchExternalUrl,
            icon: const Icon(Icons.open_in_new),
            label: Text(
              'Open & Read ${material.type.badgeLabel}',
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(LearningStatus status) {
    switch (status) {
      case LearningStatus.pending:
        return Colors.orange;
      case LearningStatus.inProgress:
        return Colors.blue;
      case LearningStatus.completed:
        return Colors.green;
    }
  }

  IconData _iconForType(EduFileType type) {
    switch (type) {
      case EduFileType.pdf:
        return Icons.picture_as_pdf;
      case EduFileType.doc:
        return Icons.description;
      case EduFileType.presentation:
        return Icons.slideshow;
      case EduFileType.video:
        return Icons.video_library;
      case EduFileType.image:
        return Icons.image;
      case EduFileType.url:
        return Icons.language;
    }
  }
}

class _VideoControlsOverlay extends StatefulWidget {
  final VideoPlayerController controller;
  const _VideoControlsOverlay({required this.controller});

  @override
  State<_VideoControlsOverlay> createState() => _VideoControlsOverlayState();
}

class _VideoControlsOverlayState extends State<_VideoControlsOverlay> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = widget.controller.value.isPlaying;

    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              if (isPlaying) {
                widget.controller.pause();
              } else {
                widget.controller.play();
              }
            });
          },
          child: Container(
            color: Colors.transparent,
            alignment: Alignment.center,
            child: AnimatedOpacity(
              opacity: isPlaying ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 44,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
