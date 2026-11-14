# test/Tarball_test.rb

lib_dir = File.expand_path(File.join('..', '..', 'lib'), __FILE__)
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

require 'minitest/autorun'
require 'minitest/mock'
require 'rubygems/package'
require 'tmpdir'
require 'zlib'
require 'Tarball'

describe Tarball do
  let(:dir){Dir.mktmpdir}
  let(:path_to_tarball){File.join(dir, 'example 1.0.tar.gz')}

  before do
    File.open(path_to_tarball, 'wb') do |file|
      Zlib::GzipWriter.wrap(file) do |gzip|
        Gem::Package::TarWriter.new(gzip) do |tar|
          tar.mkdir('example', 0755)
          tar.add_file_simple('example/start.sh', 0755, 10){|io| io.write("#!/bin/sh\n")}
        end
      end
    end
  end

  after do
    FileUtils.rm_rf(dir)
  end

  describe ".extract" do
    it "extracts into a directory it makes, keeping the mode" do
      Tarball.extract(path_to_tarball, to: File.join(dir, 'share data'))
      expect(File.executable?(File.join(dir, 'share data', 'example', 'start.sh'))).must_equal true
    end

    it "gives tar each path as an argument of its own, unquoted" do
      commands = []
      Tarball.stub(:system, ->(*command){commands << command; true}) do
        Tarball.extract('/tmp/example 1.0.tar.gz', to: File.join(dir, 'to'))
      end
      expect(commands).must_equal [['tar', '-xf', '/tmp/example 1.0.tar.gz', '-C', File.join(dir, 'to')]]
    end

    it "raises where tar fails" do
      capture_subprocess_io do
        expect{Tarball.extract(File.join(dir, 'missing.tar.gz'), to: dir)}.must_raise RuntimeError
      end
    end

    it "raises where it's given no tarball or nowhere to extract to" do
      expect(expect{Tarball.extract(nil, to: dir)}.must_raise(RuntimeError).message).must_equal 'No tarball was given.'
      expect(expect{Tarball.extract(path_to_tarball, to: nil)}.must_raise(RuntimeError).message).must_equal 'Nowhere to extract to was given.'
    end
  end

  describe "an instance" do
    it "extracts the tarball given to where it's given" do
      Tarball.new(path_to_tarball: path_to_tarball, to: File.join(dir, 'to')).extract
      expect(File.exist?(File.join(dir, 'to', 'example', 'start.sh'))).must_equal true
    end
  end
end
