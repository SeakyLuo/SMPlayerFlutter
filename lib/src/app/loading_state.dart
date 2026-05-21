import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';

class SmPlayerLoadingState extends StatelessWidget {
  const SmPlayerLoadingState({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final i18n =
        context.maybeSmPlayerI18n ??
        const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
    final label = i18n.t('nowPlaying.loading');
    return Center(
      child: Semantics(
        container: true,
        liveRegion: true,
        label: label,
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: compact ? 24 : 30,
                child: CircularProgressIndicator(
                  strokeWidth: compact ? 2.2 : 2.5,
                ),
              ),
              SizedBox(height: compact ? 10 : 14),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xff5f6f86),
                  fontSize: compact ? 13 : 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
