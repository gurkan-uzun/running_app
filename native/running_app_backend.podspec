Pod::Spec.new do |s|
  s.name             = 'running_app_backend'
  s.version          = '0.0.1'
  s.summary          = 'C++ Backend for Running App'
  s.description      = <<-DESC
A local pod to build the C++ native backend sources for the Flutter app.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  
  # Source files
  s.source_files = 'src/**/*.{cpp,c,cc}', 'include/**/*.{h,hpp}'
  
  # Include headers path
  s.public_header_files = 'include/**/*.h'
  s.pod_target_xcconfig = { 'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/include"' }
  
  s.ios.deployment_target = '12.0'
end
