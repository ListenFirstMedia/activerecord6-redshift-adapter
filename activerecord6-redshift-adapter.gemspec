Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = 'activerecord6-redshift-adapter'
  s.version = '1.1.1'
  s.summary = 'Amazon Redshift adapter for ActiveRecord '
  s.description = 'Amazon Redshift _makeshift_ adapter for ActiveRecord 6.'
  s.license = 'MIT'

  s.author = ['Nancy Foen', 'Minero Aoki', 'iamdbc', 'Vasanth Amana']
  s.email = 'vasanth@drylogics.com'
  s.homepage = 'https://github.com/drylogics/activerecord6-redshift-adapter'

  s.files = Dir.glob(['LICENSE', 'README.md', 'lib/**/*.rb'])
  s.require_path = 'lib'

  s.required_ruby_version = '>= 2.2.2'
  s.add_dependency 'pg', ['>= 1.4.6']
  s.add_dependency 'activerecord', ['>= 7.0.0']
end
