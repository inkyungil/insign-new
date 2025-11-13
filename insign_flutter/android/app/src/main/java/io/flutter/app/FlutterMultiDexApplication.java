package io.flutter.app;

import androidx.multidex.MultiDexApplication;

/**
 * FlutterMultiDexApplication is a MultiDexApplication subclass that provides
 * multidex support for Flutter applications.
 */
public class FlutterMultiDexApplication extends MultiDexApplication {
    // This class extends MultiDexApplication to enable multidex support
    // for Flutter applications that exceed the 64K method limit.
}
