import 'package:flutter_test/flutter_test.dart';
import 'package:audio_compare_plugin/audio_compare_plugin.dart';
import 'package:audio_compare_plugin/audio_compare_plugin_platform_interface.dart';
import 'package:audio_compare_plugin/audio_compare_plugin_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAudioComparePluginPlatform
    with MockPlatformInterfaceMixin
    implements AudioComparePluginPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final AudioComparePluginPlatform initialPlatform = AudioComparePluginPlatform.instance;

  test('$MethodChannelAudioComparePlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAudioComparePlugin>());
  });

  test('getPlatformVersion', () async {
    AudioComparePlugin audioComparePlugin = AudioComparePlugin();
    MockAudioComparePluginPlatform fakePlatform = MockAudioComparePluginPlatform();
    AudioComparePluginPlatform.instance = fakePlatform;

    expect(await audioComparePlugin.getPlatformVersion(), '42');
  });
}
