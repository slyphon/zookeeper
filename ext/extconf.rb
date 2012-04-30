
require 'mkmf'
require 'rbconfig'

HERE = File.expand_path(File.dirname(__FILE__))
BUNDLE = Dir.glob("zkc-*.tar.gz").first
BUNDLE_PATH = "c"

$EXTRA_CONF = ''

# CLANG!!!! jeez, if apple would only *stop* "thinking different"
if cc = RbConfig::CONFIG['CC'] && cc =~ /^gcc/
  $CC = cc
  $EXTRA_CONF = "#{$EXTRA_CONF} CC=#{$CC}"
end

$CFLAGS = "#{$CFLAGS}".gsub("$(cflags)", "").gsub("-arch ppc", "")
$LDFLAGS = "#{$LDFLAGS}".gsub("$(ldflags)", "").gsub("-arch ppc", "")
$CXXFLAGS = " -std=gnu++98 #{$CFLAGS}"
$CPPFLAGS = $ARCH_FLAG = $DLDFLAGS = ""

if RUBY_VERSION == '1.8.7'
  $CFLAGS << ' -DZKRB_RUBY_187'
end

ZK_DEBUG = (ENV['DEBUG'] or ARGV.any? { |arg| arg == '--debug' })
DEBUG_CFLAGS = " -O0 -ggdb3 -DHAVE_DEBUG"

if ZK_DEBUG
  $stderr.puts "*** Setting debug flags. ***"
  $EXTRA_CONF = "#{$EXTRA_CONF} --enable-debug"
  $CFLAGS.gsub!(/ -O[^0] /, ' ')
  $CFLAGS << DEBUG_CFLAGS
end

$includes = " -I#{HERE}/include"
$libraries = " -L#{HERE}/lib -L#{RbConfig::CONFIG['libdir']}"
$CFLAGS = "#{$includes} #{$libraries} #{$CFLAGS}"
$LDFLAGS = "#{$libraries} #{$LDFLAGS}"
$LIBPATH = ["#{HERE}/lib"]
$DEFLIBPATH = []

def safe_sh(cmd)
  puts cmd
  system(cmd)
  unless $?.exited? and $?.success?
    raise "command failed! #{cmd}"
  end
end

Dir.chdir(HERE) do
  if File.exist?("lib")
    puts "Zkc already built; run 'rake clobber' in ext/ first if you need to rebuild."
  else
    puts "Building zkc."

    unless File.exists?('c')
      puts(cmd = "tar xzf #{BUNDLE} 2>&1")
      raise "'#{cmd}' failed" unless system(cmd)
    end

    Dir.chdir(BUNDLE_PATH) do        
      configure = "./configure --prefix=#{HERE} --with-pic --without-cppunit --disable-dependency-tracking #{$EXTRA_CONF} 2>&1"
      
      configure = "env CFLAGS='#{DEBUG_CFLAGS}' #{configure}" if ZK_DEBUG

      safe_sh(configure)
      safe_sh("make  2>&1")
      safe_sh("make install 2>&1")
    end

    system("rm -rf #{BUNDLE_PATH}") unless ENV['DEBUG'] or ENV['DEV']
  end
end

# Absolutely prevent the linker from picking up any other zookeeper_mt
Dir.chdir("#{HERE}/lib") do
  system("cp -f libzookeeper_mt.a libzookeeper_mt_gem.a") 
  system("cp -f libzookeeper_mt.la libzookeeper_mt_gem.la") 
end
$LIBS << " -lzookeeper_mt_gem"


create_makefile 'zookeeper_c'

