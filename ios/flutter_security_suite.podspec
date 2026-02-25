Pod::Spec.new do |s|
  s.name             = 'flutter_security_suite'
  s.version          = '1.0.0'
  s.summary          = 'SecureBankKit - Enterprise-grade Flutter security plugin.'
  s.description      = <<-DESC
SecureBankKit provides root/jailbreak detection, certificate pinning,
screenshot protection, app integrity checks, and secure storage for Flutter apps.
                       DESC
  s.homepage         = 'https://github.com/DeepakPal25/flutter_security_suite'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Deepak Pal' => 'deepaksitapal@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '12.0'
  s.swift_version    = '5.0'
end
