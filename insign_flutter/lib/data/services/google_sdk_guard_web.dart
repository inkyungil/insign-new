import 'dart:html' as html;
import 'dart:js_util' as js_util;

const String _flagKey = '__insignGoogleSdkInitialized';

/// Returns true if the Google Identity Services SDK was already initialized
/// within the current browser page. Sets a window-scoped flag on first call so
/// hot restart or multiple widget mounts do not attempt to reinitialize.
bool markGoogleSdkInitialized() {
  final Object? value =
      js_util.hasProperty(html.window, _flagKey)
          ? js_util.getProperty(html.window, _flagKey)
          : null;

  if (value == true) {
    return true;
  }

  js_util.setProperty(html.window, _flagKey, true);
  return false;
}
