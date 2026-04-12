import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meeting_brain/core/theme/app_theme.dart';

void main() {
  test('App theme uses requested branding colors', () {
    expect(AppTheme.primary, const Color(0xFF6C63FF));
    expect(AppTheme.secondary, const Color(0xFFA29BFE));
  });
}
