import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'audio_compare_plugin_method_channel.dart';

abstract class AudioComparePluginPlatform extends PlatformInterface {
  /// Constructs a AudioComparePluginPlatform.
  AudioComparePluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static AudioComparePluginPlatform _instance = MethodChannelAudioComparePlugin();

  /// The default instance of [AudioComparePluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelAudioComparePlugin].
  static AudioComparePluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AudioComparePluginPlatform] when
  /// they register themselves.
  static set instance(AudioComparePluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
