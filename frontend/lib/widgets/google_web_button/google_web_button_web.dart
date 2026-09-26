import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi_web;

Widget buildGoogleWebSignInButton() {
  return gsi_web.renderButton(
    configuration: gsi_web.GSIButtonConfiguration(
      type: gsi_web.GSIButtonType.standard,
      theme: gsi_web.GSIButtonTheme.outline,
      size: gsi_web.GSIButtonSize.large,
      text: gsi_web.GSIButtonText.continueWith,
      shape: gsi_web.GSIButtonShape.rectangular,
      logoAlignment: gsi_web.GSIButtonLogoAlignment.left,
      minimumWidth: 320,
    ),
  );
}
