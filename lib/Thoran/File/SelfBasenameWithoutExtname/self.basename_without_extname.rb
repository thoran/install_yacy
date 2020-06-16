# Thoran/File/SelfBasenameWithoutExtname/self.basename_without_extname.rb
# Thoran::File::SelfBasenameWithoutExtname.basename_without_extname.rb

# 20200321
# 0.3.0

# Description: This returns the basename without the extension for a given path without the need to specify what the extension is because it makes use of File.extname which works that out.

# Changes:
# 1. /Thoran::File::SelfFilenameWithoutExtname/Thoran::File::SelfBasenameWithoutExtname/.

module Thoran
  module File
    module SelfBasenameWithoutExtname

      def basename_without_extname(path)
        basename(path, extname(path))
      end

    end
  end
end

File.extend(Thoran::File::SelfBasenameWithoutExtname)
