import 'package:cached_network_image/cached_network_image.dart';
import 'package:corpsapp/models/event_summary.dart' as event_summary;
import 'package:corpsapp/models/session_type_helper.dart';
import 'package:corpsapp/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventSummaryCard extends StatelessWidget {
  final event_summary.EventSummary summary;
  final bool isFull;
  final bool isExpanded;

  const EventSummaryCard({
    super.key,
    required this.summary,
    this.isFull = false,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final smallScreen = screenWidth < 360;

    if (summary.requiresBooking) {
      return _buildBookableCard(smallScreen);
    }

    return _buildContentCard(context, smallScreen);
  }

  Widget _buildBookableCard(bool smallScreen) {
    return ClipRRect(
      borderRadius:
          isExpanded
              ? const BorderRadius.vertical(bottom: Radius.circular(0))
              : const BorderRadius.all(Radius.circular(7)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _bookableHeading(summary, smallScreen),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _summaryLeft(summary, smallScreen)),
                    Expanded(
                      child: _bookableSummaryRight(summary, smallScreen),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isFull) _bookedOutBanner(),
        ],
      ),
    );
  }

  Widget _buildContentCard(BuildContext context, bool smallScreen) {
    final isPromo = summary.isPromotional;
    final palette = _contentPalette(summary);
    final imageUrls = summary.eventImageUrls;
    final hasImage = imageUrls.isNotEmpty;
    final showVisibilityDates = !summary.isPromotional && !summary.isAnnouncement;
    final normalizedLocation = summary.locationName.trim().toLowerCase();
    final normalizedTitle = summary.displayTitle.trim().toLowerCase();
    final showLocation =
        normalizedLocation.isNotEmpty && normalizedLocation != normalizedTitle;
    final chipTintPrimary = isPromo ? palette.first : const Color(0xFF4B5563);
    final chipTintSecondary = isPromo ? palette.last : const Color(0xFF374151);

    final metaChips = <Widget>[
      if (showVisibilityDates)
        _contentMetaPill(
          icon: Icons.calendar_today_rounded,
          label: 'From ${_formatDate(summary.startDate)}',
          smallScreen: smallScreen,
          tint: chipTintPrimary,
        ),
      if (showVisibilityDates)
        _contentMetaPill(
          icon: Icons.event_available_rounded,
          label: 'To ${_formatDate(summary.toDate)}',
          smallScreen: smallScreen,
          tint: chipTintSecondary,
        ),
      if (showLocation)
        _contentMetaPill(
          icon: Icons.place_outlined,
          label: summary.locationName,
          smallScreen: smallScreen,
          tint:
              isPromo
                  ? chipTintPrimary.withValues(alpha: 0.9)
                  : const Color(0xFF1F2937),
        ),
    ];

    return ClipRRect(
      borderRadius:
          isExpanded
              ? const BorderRadius.vertical(bottom: Radius.circular(0))
              : const BorderRadius.all(Radius.circular(7)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _contentHero(
            context: context,
            imageUrls: imageUrls,
            hasImage: hasImage,
            palette: palette,
            isPromo: isPromo,
            smallScreen: smallScreen,
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: smallScreen ? 18 : 20,
              vertical: smallScreen ? 18 : 20,
            ),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _contentTypePill(summary, smallScreen),
                    const Spacer(),
                    Icon(
                      isPromo
                          ? Icons.campaign_rounded
                          : Icons.info_outline_rounded,
                      color: AppColors.normalText.withValues(alpha: 0.9),
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  summary.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.normalText,
                      fontSize: smallScreen ? 15 : 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (metaChips.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: metaChips),
                ],
              ],
            ),
          ),
          _contentBanner(summary, palette),
        ],
      ),
    );
  }

  Widget _contentHero({
    required BuildContext context,
    required List<String> imageUrls,
    required bool hasImage,
    required List<Color> palette,
    required bool isPromo,
    required bool smallScreen,
  }) {
    final heroHeight =
        hasImage
            ? (isPromo
                ? (smallScreen ? 138.0 : 164.0)
                : (smallScreen ? 126.0 : 148.0))
            : (isPromo
                ? (smallScreen ? 96.0 : 114.0)
                : (smallScreen ? 86.0 : 104.0));

    if (!hasImage) {
      final fallbackGradient =
          isPromo
              ? [
                palette.first.withValues(alpha: 0.95),
                palette.last.withValues(alpha: 0.85),
              ]
              : [const Color(0xFF1B1B1B), const Color(0xFF2A2A2A)];
      return Container(
        height: heroHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: fallbackGradient,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPromo ? Icons.bolt_rounded : Icons.announcement_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                summary.isPromotional
                    ? 'FEATURED PROMO'
                    : 'COMMUNITY ANNOUNCEMENT',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: smallScreen ? 12 : 13,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            allowImplicitScrolling: true,
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              final imageUrl = imageUrls[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap:
                        () => _openImageGallery(
                          context,
                          imageUrls,
                          initialIndex: index,
                        ),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder:
                          (_, __) => const ColoredBox(
                            color: Colors.white10,
                            child: Center(
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                      errorWidget:
                          (_, __, ___) => ColoredBox(
                            color: palette.first.withValues(alpha: 0.75),
                            child: const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                    ),
                  ),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: isPromo ? 0.05 : 0.2),
                            Colors.black.withValues(alpha: isPromo ? 0.45 : 0.6),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            right: 8,
            top: 8,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.open_in_full_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Expand',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (imageUrls.length > 1)
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Swipe',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (imageUrls.length > 1)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${imageUrls.length} images',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openImageGallery(
    BuildContext context,
    List<String> imageUrls, {
    required int initialIndex,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder:
            (_) => _EventImageGalleryView(
              imageUrls: imageUrls,
              initialIndex: initialIndex,
            ),
      ),
    );
  }

  Widget _contentTypePill(event_summary.EventSummary s, bool smallScreen) {
    final isPromo = s.isPromotional;
    final label = s.isPromotional ? 'PROMOTIONAL' : 'ANNOUNCEMENT';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: smallScreen ? 8 : 10,
        vertical: smallScreen ? 4 : 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        color:
            isPromo
                ? AppColors.primaryColor.withValues(alpha: 0.12)
                : Colors.grey.shade100,
        border: Border.all(
          color:
              isPromo
                  ? AppColors.primaryColor.withValues(alpha: 0.6)
                  : AppColors.normalText.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.normalText,
          fontWeight: FontWeight.w800,
          fontSize: smallScreen ? 9.6 : 10.8,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _contentMetaPill({
    required IconData icon,
    required String label,
    required bool smallScreen,
    required Color tint,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: smallScreen ? 240 : 290),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: smallScreen ? 8 : 10,
          vertical: smallScreen ? 6 : 7,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFF4F5F6),
          border: Border.all(color: tint.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: smallScreen ? 13 : 14,
              color: tint.withValues(alpha: 0.95),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.normalText,
                  fontSize: smallScreen ? 12 : 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contentBanner(event_summary.EventSummary s, List<Color> palette) {
    final label =
        s.isPromotional
            ? 'BOOK VIA WEBSITE LINK IN DESCRIPTION'
            : 'ANNOUNCEMENT';
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: s.isPromotional ? 5 : 7,
        horizontal: 12,
      ),
      decoration:
          s.isPromotional
              ? BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [palette.first, palette.last],
                ),
              )
              : const BoxDecoration(color: AppColors.background),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          fontFamily: 'WinnerSans',
        ),
      ),
    );
  }

  List<Color> _contentPalette(event_summary.EventSummary s) {
    if (s.isPromotional) {
      return const [AppColors.primaryColor, Color(0xFF2B5E9E)];
    }
    return const [Color(0xFF4B5563), Color(0xFF374151)];
  }

  Widget _bookedOutBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: const BoxDecoration(color: AppColors.errorColor),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 6),
          Text(
            'BOOKED OUT',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              fontFamily: 'WinnerSans',
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookableHeading(event_summary.EventSummary s, bool smallScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            s.locationName,
            style: TextStyle(
              color: AppColors.normalText,
              fontSize: smallScreen ? 14 : 16,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          SessionTypeHelper.format(s.sessionType),
          style: TextStyle(
            color: AppColors.normalText,
            fontSize: smallScreen ? 14 : 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _summaryLeft(event_summary.EventSummary s, bool smallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _weekdayFull(s.startDate),
          style: TextStyle(
            color: AppColors.normalText,
            fontSize: smallScreen ? 20 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          _formatDate(s.startDate),
          style: TextStyle(
            color: AppColors.normalText,
            fontSize: smallScreen ? 12 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _bookableSummaryRight(event_summary.EventSummary s, bool smallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Starts    ',
                style: TextStyle(
                  color: AppColors.normalText,
                  fontWeight: FontWeight.bold,
                  fontSize: smallScreen ? 10 : 12,
                ),
              ),
              TextSpan(
                text: formatTime(s.startTime),
                style: TextStyle(
                  color: AppColors.normalText,
                  fontWeight: FontWeight.bold,
                  fontSize: smallScreen ? 14 : 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Ends    ',
                style: TextStyle(
                  color: AppColors.normalText,
                  fontWeight: FontWeight.bold,
                  fontSize: smallScreen ? 10 : 12,
                ),
              ),
              TextSpan(
                text: formatTime(s.endTime),
                style: TextStyle(
                  color: AppColors.normalText,
                  fontWeight: FontWeight.bold,
                  fontSize: smallScreen ? 14 : 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _weekdayFull(DateTime d) {
    const week = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return week[d.weekday - 1];
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String formatTime(String time) {
    final t = time.trim();
    if (t.isEmpty) return '--';
    try {
      if (RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(t)) {
        final parsed = DateFormat("HH:mm:ss").parse(t);
        return DateFormat("hh:mma").format(parsed);
      }
      if (RegExp(r'^\d{2}:\d{2}$').hasMatch(t)) {
        final parsed = DateFormat("HH:mm").parse(t);
        return DateFormat("hh:mma").format(parsed);
      }
    } catch (_) {}
    return t;
  }
}

class _EventImageGalleryView extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _EventImageGalleryView({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_EventImageGalleryView> createState() => _EventImageGalleryViewState();
}

class _EventImageGalleryViewState extends State<_EventImageGalleryView> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1}/${widget.imageUrls.length}'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.imageUrls.length,
            onPageChanged: (value) => setState(() => _currentIndex = value),
            itemBuilder: (context, index) {
              final imageUrl = widget.imageUrls[index];
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder:
                        (_, __) => const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                    errorWidget:
                        (_, __, ___) => const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white70,
                            size: 34,
                          ),
                        ),
                  ),
                ),
              );
            },
          ),
          if (widget.imageUrls.length > 1)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.all(Radius.circular(100)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text(
                      'Swipe to view more',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
