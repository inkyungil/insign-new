import 'dart:html' as html;
import 'dart:js_util';

const String _flagKey = '__insignGoogleSdkInitialized';

/// Returns true if the Google Identity Services SDK was already initialized
/// within the current browser page. Sets a window-scoped flag on first call so
/// hot restart or multiple widget mounts do not attempt to reinitialize.
bool markGoogleSdkInitialized() {
  if (hasProperty(html.window, _flagKey)) {
    final value = getProperty(html.window, _flagKey);
    if (value == true) {
      return true;
    }
  }

  setProperty(html.window, _flagKey, true);
  return false;
}

