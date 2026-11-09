# Thoran/Kernel/RequireGem/require_gem.rb
# Thoran::Kernel::RequireGem#require_gem.rb

# 20260925
# 0.1.0

# Changes:
# -/0: Activate gem_name before requiring, so that the named gem is the one loaded where more than one gem provides the load string.
# 1. ~ require_gem(): + gem(gem_name) if gem_name, before each require.

module Thoran
  module Kernel
    module RequireGem

      def require_gem(load_string, gem_name: nil)
        gem(gem_name) if gem_name
        require load_string
      rescue LoadError
        if gem_name
          system("gem install #{gem_name}")
        else
          system("gem install #{load_string}")
        end
        Gem.clear_paths
        gem(gem_name) if gem_name
        require load_string
      end

    end
  end
end

Kernel.include(Thoran::Kernel::RequireGem)
