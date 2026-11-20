ENV['NODE_PATH'] = [File.expand_path('NativeUI/node_modules', __dir__), ENV['NODE_PATH']].compact.join(File::PATH_SEPARATOR)

require_relative 'NativeUI/node_modules/react-native/scripts/react_native_pods'

platform :ios, '17.0'
project 'TuJu.xcodeproj'
prepare_react_native_project!

target 'TuJu' do
  native_app = File.join(__dir__, 'NativeUI')
  config = use_native_modules!(['node', '-e', "process.chdir('NativeUI'); process.argv = ['node', 'cli', 'config']; require('./NativeUI/node_modules/@react-native-community/cli').run()"])
  use_react_native!(
    :path => config[:reactNativePath],
    :app_path => native_app,
    :config_file_dir => native_app
  )

  post_install do |installer|
    react_native_post_install(installer, config[:reactNativePath], :mac_catalyst_enabled => true)
    # iOS 17 maps to Mac Catalyst 14. Some pod targets still declare macOS 10.15.
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |configuration|
        configuration.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
        configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
      end
    end
  end
end
