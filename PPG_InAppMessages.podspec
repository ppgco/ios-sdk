Pod::Spec.new do |s|
  s.name             = 'PPG_InAppMessages'
  s.version          = '4.1.0'
  s.summary          = 'PushPushGo In-App Messages SDK for iOS.'

  # A more detailed description of the pod.
  s.description      = <<-DESC
                       The PushPushGo In-App Messages SDK allows easy integration of in-app messaging services for iOS applications.
                       Features include audience targeting, custom triggers, and seamless integration with push notifications.
                       DESC

  s.homepage         = 'https://pushpushgo.com/pl/'
  s.license          = 'MIT'
  s.authors          = { 'Adam' => 'adam@pushpushgo.com', 'Mateusz' => 'mateusz@pushpushgo.com' }
  
  s.platform         = :ios
  
  s.source = { :git => 'https://github.com/ppgco/ios-sdk.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.3'

  s.source_files = 'Sources/PPG_InAppMessages/**/*.{h,m,swift}'

  # Framework dependencies
  s.frameworks = 'UIKit', 'WebKit', 'Foundation'

end
