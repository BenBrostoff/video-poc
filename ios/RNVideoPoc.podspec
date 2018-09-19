
Pod::Spec.new do |s|
  s.name         = "RNVideoPoc"
  s.version      = "1.0.0"
  s.homepage     = "http://benbrostoff.github.io"
  s.summary      = "RNVideoPoc"
  s.description  = <<-DESC
                  RNVideoPoc by Ben
                   DESC
  s.license      = "MIT"
  # s.license      = { :type => "MIT", :file => "FILE_LICENSE" }
  s.author             = { "author" => "author@domain.cn" }
  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/author/RNVideoPoc.git", :tag => "1.0.0" }
  s.source_files  = "RNVideoPoc/**/*.{h,m}"
  s.requires_arc = true


  s.dependency "React"
  #s.dependency "others"

end

  
