import 'package:flutter/material.dart';

class WaitlistDialog extends StatelessWidget {
  final bool isOn;
  final bool done;
  final bool working;
  final String detail;
  final String? error;
  final VoidCallback onClose;
  final void Function(StateSetter) onConfirm;

  final Color primary;
  final Color danger;
  final Color border;
  final TextStyle titleStyle;
  final TextStyle bodyStyle;

  const WaitlistDialog({
    super.key,
    required this.isOn,
    required this.done,
    required this.working,
    required this.detail,
    required this.error,
    required this.onClose,
    required this.onConfirm,
    required this.primary,
    required this.danger,
    required this.border,
    required this.titleStyle,
    required this.bodyStyle,
  });

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (ctx, setSB) {
        final joining = !isOn;
        final iconData = joining ? Icons.block : Icons.notifications_off;
        final ctaLabel = joining ? 'JOIN WAITLIST' : 'LEAVE WAITLIST';
        final ctaColor = joining ? primary : danger;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black, Colors.black],
                  ),
                  border: Border.all(color: border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.45),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: done
                      ? _SuccessContent(
                          joining: joining,
                          detail: detail,
                          primary: primary,
                          titleStyle: titleStyle,
                          bodyStyle: bodyStyle,
                          onClose: () => Navigator.of(ctx).pop(),
                        )
                      : _ConfirmContent(
                          joining: joining,
                          detail: detail,
                          error: error,
                          working: working,
                          ctaColor: ctaColor,
                          ctaLabel: ctaLabel,
                          iconData: iconData,
                          primary: primary,
                          danger: danger,
                          titleStyle: titleStyle,
                          bodyStyle: bodyStyle,
                          onConfirm: () => onConfirm(setSB),
                          onCancel: () => Navigator.of(ctx).pop(),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// split into private widgets for clarity
class _SuccessContent extends StatelessWidget {
  final bool joining;
  final String detail;
  final Color primary;
  final TextStyle titleStyle;
  final TextStyle bodyStyle;
  final VoidCallback onClose;

  const _SuccessContent({
    required this.joining,
    required this.detail,
    required this.primary,
    required this.titleStyle,
    required this.bodyStyle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('success'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: TextButton(
            onPressed: onClose,
            child: const Text('OK', style: TextStyle(color: Colors.white70)),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: primary, width: 2),
            color: primary.withOpacity(.08),
          ),
          child: Icon(
            joining ? Icons.notifications_active : Icons.check_circle,
            color: primary,
            size: 34,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          joining ? 'You’re on the waitlist' : 'Notifications turned off',
          textAlign: TextAlign.center,
          style: titleStyle,
        ),
        const SizedBox(height: 6),
        Text(detail, textAlign: TextAlign.center, style: bodyStyle),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'CLOSE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfirmContent extends StatelessWidget {
  final bool joining;
  final String detail;
  final String? error;
  final bool working;
  final Color ctaColor;
  final String ctaLabel;
  final IconData iconData;
  final Color primary;
  final Color danger;
  final TextStyle titleStyle;
  final TextStyle bodyStyle;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ConfirmContent({
    required this.joining,
    required this.detail,
    required this.error,
    required this.working,
    required this.ctaColor,
    required this.ctaLabel,
    required this.iconData,
    required this.primary,
    required this.danger,
    required this.titleStyle,
    required this.bodyStyle,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('confirm'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: TextButton(
            onPressed: onCancel,
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: primary, width: 2),
            color: primary.withOpacity(.08),
          ),
          child: Icon(iconData, color: primary, size: 34),
        ),
        const SizedBox(height: 12),
        Text(
          joining ? 'No Seats Available' : 'Stop Notifications?',
          textAlign: TextAlign.center,
          style: titleStyle,
        ),
        const SizedBox(height: 6),
        Text(
          joining
              ? "Don't worry! You may join the waitlist and we will inform you if a seat becomes available."
              : "You won’t receive alerts for this event anymore.",
          textAlign: TextAlign.center,
          style: bodyStyle,
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              const Icon(Icons.event, size: 16, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  detail,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: working ? null : onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: ctaColor,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: working
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    ctaLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
