Pod::Spec.new do |spec|

  spec.name         = 'BluetoothCentral'
  spec.version      = '1.0.0'
  spec.summary      = 'A bluetooth central for managing scan, connection, and peripherals'
  spec.homepage     = 'https://evanxlh.github.io'
  spec.license      = { :type => 'MIT' }
  spec.author       = { 'Evan Xie' => 'evanxie.mr@foxmail.com' }

  spec.swift_version = '5.0'
  spec.ios.deployment_target = '9.0'
  spec.osx.deployment_target = '10.13'
  spec.tvos.deployment_target = '10.0'
  spec.watchos.deployment_target = '3.0'

  spec.source       = { :git => 'https://github.com/evanxlh/BluetoothCentral.git', :tag => 'spec.version' }
  spec.source_files  = 'Source/*.{swift}', 'Source/**/*.{swift}'
  
  spec.dependency 'ObservationLite'
end
