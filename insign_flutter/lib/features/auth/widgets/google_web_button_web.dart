import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi;

Widget buildGoogleWebButton() {
  return ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48, maxHeight: 54),
    child: gsi.renderButton(
      configuration: gsi.GSIButtonConfiguration(
        type: gsi.GSIButtonType.standard,
        theme: gsi.GSIButtonTheme.outline,
        size: gsi.GSIButtonSize.large,
        shape: gsi.GSIButtonShape.pill,
        text: gsi.GSIButtonText.continueWith,
      ),
    ),
  );
}
