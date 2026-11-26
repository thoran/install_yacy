# YaCy/Adoptium.rb
# YaCy::Adoptium

require 'digest'
require 'fileutils'
require 'json'
require 'open-uri'
require 'rbconfig'
require 'Tarball'

module YaCy
  # Adoptium's Temurin JRE of the latest long-term release, a JRE rather than a JDK since YaCy only runs Java. Each module using this one gives its own adoptium_os, adoptium_dir and adoptium_java_path, and includes YaCy::Download and YaCy::Java.
  module Adoptium
    def adoptium_api_url
      'https://api.adoptium.net/v3'
    end

    def latest_lts_java_version
      @latest_lts_java_version ||= JSON.parse(URI.open("#{adoptium_api_url}/info/available_releases").read)['most_recent_lts']
    end

    def adoptium_architecture
      cpu = RbConfig::CONFIG['host_cpu']
      {'x86_64' => 'x64', 'amd64' => 'x64', 'arm64' => 'aarch64'}.fetch(cpu, cpu)
    end

    def adoptium_jre_package
      @adoptium_jre_package ||= (
        url = "#{adoptium_api_url}/assets/latest/#{latest_lts_java_version}/hotspot?architecture=#{adoptium_architecture}&image_type=jre&os=#{adoptium_os}&vendor=eclipse"
        asset = JSON.parse(URI.open(url).read).first
        abort("Adoptium has no Java runtime for #{adoptium_os} on #{adoptium_architecture}. Install Java #{YaCy::Java::MINIMUM_JAVA_VERSION} or later, or choose another --java.") unless asset
        asset['binary']['package']
      )
    end

    def adoptium_jre_tarball
      downloaded_path(adoptium_jre_package['link'])
    end

    def adoptium_jre_checksum_matches?
      Digest::SHA256.file(adoptium_jre_tarball).hexdigest == adoptium_jre_package['checksum']
    end

    # The newest of the JREs unpacked into adoptium_dir.
    def adoptium_java
      Dir.glob(File.join(adoptium_dir, 'jdk-*-jre', *adoptium_java_path)).max
    end

    def adoptium_java_installed?
      suitable_java?(adoptium_java)
    end

    def install_adoptium_java
      announce("installing Adoptium's Temurin #{latest_lts_java_version} JRE into #{adoptium_dir} (#{adoptium_jre_package['size'] / 1_000_000} MB).")
      download(adoptium_jre_package['link'])
      abort("#{adoptium_jre_tarball} doesn't match Adoptium's checksum. Delete it, and run yacy again.") unless adoptium_jre_checksum_matches?
      Tarball.extract(adoptium_jre_tarball, to: adoptium_dir)
    end

    # Each JRE unpacked into adoptium_dir, by yacy or as yacy would.
    def adoptium_jres
      Dir.glob(File.join(adoptium_dir, 'jdk-*-jre'))
    end

    def adoptium_jre_downloads
      Dir.glob(File.join(download_dir, "OpenJDK*-jre_*_#{adoptium_os}_hotspot_*.tar.gz"))
    end

    def remove_adoptium_jre_downloads
      FileUtils.rm_f(adoptium_jre_downloads, verbose: true) unless adoptium_jre_downloads.empty?
    end

    def remove_adoptium_java
      FileUtils.rm_rf(adoptium_jres, verbose: true) unless adoptium_jres.empty?
      remove_adoptium_jre_downloads
    end

    def give_adoptium_java_kept
      announce("Adoptium's JRE is left in #{adoptium_jres.join(', ')}. yacy uninstall --jre=remove removes it.") unless adoptium_jres.empty?
    end
  end
end
