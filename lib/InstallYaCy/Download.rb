# InstallYaCy/Download.rb
# InstallYaCy::Download

# 20261116
# 0.0.0

require 'fileutils'
require 'Kernel/require_gem'
require 'open-uri'

require_gem 'nokogiri'

module InstallYaCy
  module Download
    def download_site
      'https://download.yacy.net'
    end

    # The last file on download.yacy.net whose name matches, which is the latest.
    def latest_filename_matching(pattern)
      doc = Nokogiri.HTML(URI.open(download_site))
      doc.search('a').map{|e| e[:href]}.reverse.detect{|e| e =~ pattern}
    end

    def url_for(filename)
      "#{download_site}/#{filename}"
    end

    def download_dir
      File.join(Dir.home, 'Downloads')
    end

    def downloaded_path(url)
      File.join(download_dir, File.basename(url))
    end

    # Downloads into ~/Downloads, made where there isn't one, unless it's there already.
    def download(url)
      return if File.exist?(downloaded_path(url))
      FileUtils.mkdir_p(download_dir)
      File.open(downloaded_path(url), 'wb') do |file|
        file.write(URI.open(url).read)
      end
    end
  end
end
