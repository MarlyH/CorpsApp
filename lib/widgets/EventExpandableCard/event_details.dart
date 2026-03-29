import 'package:corpsapp/fragments/home_fragment.dart';
import 'package:corpsapp/models/event_summary.dart' as event_summary;
import 'package:corpsapp/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

class EventDetailsCard extends StatelessWidget {
  final event_summary.EventSummary summary;
  final Future<EventDetail> detailFut;

  const EventDetailsCard({
    super.key,
    required this.summary,
    required this.detailFut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(7)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeatsRow(summary),
          const SizedBox(height: 12),
          _buildAddress(),
          const SizedBox(height: 12),
          _buildDescription(),
        ],
      ),
    );
  }

  Widget _buildSeatsRow(event_summary.EventSummary s) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.event_seat, color: Colors.white, size: 20),
      const SizedBox(width: 8),
      RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${s.availableSeatsCount} ',
              style: TextStyle(fontSize: 20),
            ),
            TextSpan(text: 'AVAILABLE', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    ],
  );

  Widget _buildAddress() => FutureBuilder<EventDetail>(
    future: detailFut,
    builder: (ctx, snap) {
      final addr = snap.data?.address ?? '';
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_on, size: 20),
          const SizedBox(width: 4),
          Text(addr, style: TextStyle(fontSize: 16)),
        ],
      );
    },
  );

  Widget _buildDescription() => FutureBuilder<EventDetail>(
    future: detailFut,
    builder: (ctx, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        );
      }
      if (snap.hasError) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Error loading details',
            style: TextStyle(color: AppColors.errorColor),
          ),
        );
      }

      if (snap.data?.description == null || snap.data!.description.isEmpty) {
        return const SizedBox.shrink(); // no description, no padding
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _LinkifiedDescriptionText(
          text: snap.data!.description,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
          linkStyle: const TextStyle(
            color: AppColors.primaryColor,
            fontSize: 16,
            decoration: TextDecoration.underline,
          ),
        ),
      );
    },
  );
}

class _LinkifiedDescriptionText extends StatefulWidget {
  const _LinkifiedDescriptionText({
    required this.text,
    required this.style,
    required this.linkStyle,
  });

  final String text;
  final TextStyle style;
  final TextStyle linkStyle;

  @override
  State<_LinkifiedDescriptionText> createState() =>
      _LinkifiedDescriptionTextState();
}

class _LinkifiedDescriptionTextState extends State<_LinkifiedDescriptionText> {
  static final RegExp _urlRegex = RegExp(
    r'https?:\/\/[^\s]+',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: _normalizeToMarkdown(widget.text),
      styleSheet: MarkdownStyleSheet(
        p: widget.style,
        a: widget.linkStyle,
        listBullet: widget.style.copyWith(color: widget.style.color),
      ),
      onTapLink: (text, href, title) {
        final String? url = href ?? _extractFirstUrl(text);
        if (url != null) {
          _openUrl(url);
        }
      },
    );
  }

  String _normalizeToMarkdown(String text) {
    final StringBuffer output = StringBuffer();
    int currentIndex = 0;

    for (final match in _urlRegex.allMatches(text)) {
      if (match.start > currentIndex) {
        output.write(text.substring(currentIndex, match.start));
      }

      String urlText = text.substring(match.start, match.end);
      final String trailing = _extractTrailingPunctuation(urlText);
      if (trailing.isNotEmpty) {
        urlText = urlText.substring(0, urlText.length - trailing.length);
      }

      if (urlText.isNotEmpty) {
        if (_isAlreadyMarkdownLink(text, match.start)) {
          output.write(urlText);
        } else {
          output.write('[$urlText]($urlText)');
        }
      }

      if (trailing.isNotEmpty) {
        output.write(trailing);
      }

      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      output.write(text.substring(currentIndex));
    }

    return output.toString();
  }

  bool _isAlreadyMarkdownLink(String source, int urlStart) {
    if (urlStart < 2) {
      return false;
    }
    return source[urlStart - 1] == '(' && source[urlStart - 2] == ']';
  }

  String? _extractFirstUrl(String value) {
    final Match? match = _urlRegex.firstMatch(value);
    if (match == null) {
      return null;
    }
    return value.substring(match.start, match.end);
  }

  String _extractTrailingPunctuation(String value) {
    int cut = value.length;

    while (cut > 0) {
      final char = value[cut - 1];
      if (!_isTrailingPunctuation(char)) {
        break;
      }
      cut--;
    }

    return value.substring(cut);
  }

  bool _isTrailingPunctuation(String char) {
    return char == '.' ||
        char == ',' ||
        char == ';' ||
        char == ':' ||
        char == '!' ||
        char == '?' ||
        char == ')' ||
        char == ']' ||
        char == '}';
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this link.')),
      );
    }
  }
}
