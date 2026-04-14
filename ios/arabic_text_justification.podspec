Pod::Spec.new do |s|
  s.name             = 'arabic_text_justification'
  s.version          = '0.1.0'
  s.summary          = 'A new Flutter FFI plugin project.'
  s.description      = <<-DESC
A new Flutter FFI plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.{h,mm}'
  s.public_header_files = 'Classes/**/*.h'
  s.vendored_frameworks = 'Frameworks/arabic_text_justification.xcframework'
  s.preserve_paths   = 'Frameworks/arabic_text_justification.xcframework'
  s.libraries        = 'c++'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64',
    'CLANG_CXX_LIBRARY' => 'libc++',
  }
  s.user_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64',
  }
  s.swift_version = '5.0'
end
