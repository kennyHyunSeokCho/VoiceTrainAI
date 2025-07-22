
import 'audio_compare_plugin_platform_interface.dart';

class AudioComparePlugin {
  Future<String?> getPlatformVersion() {
    return AudioComparePluginPlatform.instance.getPlatformVersion();
  }
}
