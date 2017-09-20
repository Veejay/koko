#! /usr/bin/ruby

require "json"

class Koko
  attr_reader :command, :environment, :instance_type, :configuration
  
  AVAILABLE_COMMANDS = %w(logs htop console ssh)
  AVAILABLE_ENVIRONMENTS = %w(production vodka)
  AVAILABLE_INSTANCE_TYPES = %w(apps sites images thumbs)

  def initialize arguments
    case arguments.size
    when 0
      abort(help_message)
    when 1
      refresh_configuration
    when 2
      open_console
    when 3
      @command, @environment, @instance_type = *options.map(&:strip)
      @configuration = JSON.parse(File.read('.koko.config.json')).fetch(@environment)
      unless arguments_valid?
        Kernel.abort "Invalid arguments"
      end
      command = KokoCommand.new(self)
      command.run
    else
      abort <<-ERROR_MESSAGE
\e[31mERROR\e[0m: Too many arguments
#{help_message}
      ERROR_MESSAGE
    end
  end

  def help_message
    <<-HELP

---------------------------------------------
\e[34mUsage\e[0m: koko \e[32mCOMMAND ENVIRONMENT INSTANCE_TYPE\e[0m
---------------------------------------------

\e[32mCOMMAND\e[0m:\t[logs htop console ssh]
\e[32mENVIRONMENT\e[0m:\t[production vodka]
\e[32mINSTANCE_TYPE\e[0m:\t[apps sites thumbs images]     
    HELP
  end

  def refresh_configuration
    config = {}.tap do |cfg|
      AVAILABLE_ENVIRONMENTS.each do |env|
        output = `ey servers --environment #{env} --account 'pikock'`
        parsed = output
          .split("\n")
          .select{ |line| line =~ /\Aec2-/ }
          .map{ |line| line.split(/\s+/).map(&:strip) }
          .reduce([]) { |memo, aws_instance|
            address, type = *[aws_instance.first, aws_instance.last]
            memo.push({type: type, address: address})
            memo
          }
        cfg.store(env, parsed)
      end
    end
    File.open(".koko.config.json", "wb") do |file|
      file.write JSON.pretty_generate(config)
    end 
    puts "Configuration is up to date"
  end

  def open_console
    `ttab ey console -e #{environment} -c pikock`
  end

  def valid_command?
    AVAILABLE_COMMANDS.include?(command) 
  end

  def valid_environment?
    AVAILABLE_ENVIRONMENTS.include?(environment)
  end

  def valid_instance_type?
    AVAILABLE_INSTANCE_TYPES.include?(instance_type)
  end

  def arguments_valid?
    valid_command? && valid_environment? && valid_instance_type?
  end
end

class KokoCommand
  # options is a Koko object containing the *command*, the *environment* and the *instance_type*
  attr_reader :configuration, :command, :environment, :instance_type

  LOG_FILE_NAMES = {
    sites: "background_jobs.log",
    images: "image_processor.log",
    thumbs: "thumb_processor.log",
    apps: "production.log"
  }
  
  def initialize options
    # Find how to avoid repetition here (instance_variable_set?)
    @configuration = options.configuration
    @command = options.command
    @environment = options.environment
    @instance_type = options.instance_type
  end

  def host_instance type
    case type
    when 'images', 'sites'
      'workers'
    when 'apps'
      'app'
    else
      type
    end
  end

  def hosts
    rgx = /\A#{host_instance(instance_type)}/
    configuration
    .select { |config|
      config.fetch('type') =~ rgx
    }
    .map{ |config| 
      config.fetch('address')
    }
  end

  def run
    case @command
    # FIXME: HARDCODED AS APP SERVERS HERE BUT WE WANT TO BE ABLE TO GET HTOP FOR ALL KINDS OF INSTANCES
    when 'htop'
      `ttab ey ssh "/usr/bin/htop" -t --app-servers -e #{environment} -c pikock` 
    when 'ssh'
      hosts.each do |host|
        `ttab ssh deploy@#{host} "cd /data/ecosystemgold/current"`
      end
    when 'logs'
      case instance_type
      when *Koko::AVAILABLE_INSTANCE_TYPES
        hosts.each do |host|
          `ttab ssh deploy@#{host} "tail -f /data/ecosystemgold/current/log/#{LOG_FILE_NAMES.fetch(instance_type.to_sym)}"`
        end
      end
    end
  end
end

Koko.new(ARGV)
