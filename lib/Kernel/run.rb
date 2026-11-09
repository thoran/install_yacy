# Kernel/run.rb
# Kernel#run

# 20261025
# 0.3.1

# Changes since 0.3.0:
# 1. ~ Kernel#run: capture: issues the command with IO.popen rather than backticks, so as several arguments reach the command as given, as they do without capture:, rather than being joined into a shell string; a single string is still run by the shell.

module Kernel

  def run(*command, capture: false, dry_run: false, show: false, raise_on_failure: true)
    if show
      if dry_run
        puts "DRY RUN *** #{command.join(' ')} *** DRY RUN"
      else
        puts command.join(' ')
      end
    end
    unless dry_run
      if capture
        output = IO.popen(command.size == 1 ? command.first : command, &:read).strip
        if !$?.success? && raise_on_failure
          raise "#{command.inspect} failed with exit code #{$?.exitstatus}."
        end
        output # Return the output of issuing the command.
      else
        system(*command)
        success = $?.success?
        if !success && raise_on_failure
          raise "#{command.inspect} failed with exit code #{$?.exitstatus}."
        end
        success # Return the success or failure of issuing the command.
      end
    else # Dry runs always succeed.
      true
    end
  end

end
