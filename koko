#! /usr/bin/ruby

require "json"

class Koko
  attr_reader :command, :environment, :instance_type, :configuration
  
  AVAILABLE_COMMANDS = %w(logs htop console ssh)
  AVAILABLE_ENVIRONMENTS = %w(production vodka)
  AVAILABLE_INSTANCE_TYPES = %w(apps sites images thumbs)

  def initialize options
    if options.size == 0
      display_help
      abort("\n")
    end
    @command, @environment, @instance_type = *options.map(&:strip)
    if @command.eql?("console")
      @instance_type = "apps"
    end    
    if @command.eql?("refresh")
      refresh_configuration
    else
      @configuration = JSON.parse(File.read('.koko.config.json')).fetch(@environment)
      unless arguments_valid?
        Kernel.abort "Invalid arguments"
      end
      command = KokoCommand.new(self)
      command.run
    end
  end

  def display_help
    puts <<-HELP

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
        parsed = output.split("\n").select{|line| line =~ /\Aec2-/}.map{|line| line.split(/\s+/).map(&:strip)}.reduce([]) do |memo, aws_instance|
          address, type = *[aws_instance.first, aws_instance.last]
          memo.push({type: type, address: address})
          memo
        end
        cfg.store(env, parsed)
      end
    end
    File.open(".koko.config.json", "wb") do |file|
      file.write JSON.pretty_generate(config)
    end 
    puts "Successfully refreshed configuration"
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
  def initialize options
    @configuration = options.configuration
    @command = options.command
    @environment = options.environment
    @instance_type = options.instance_type
  end

  def host_instance type
    if ['images', 'sites'].include? type
    puts "workers"
      'workers'
    else
      if type.eql?('apps')
        'app'
      else
        type
      end
    end
  end

  def hosts
    configuration.select { |config|
      config.fetch('type') =~ /\A#{host_instance(instance_type)}/
    }.map{ |config| 
      config.fetch('address')
    }
  end

  def run
    case @command
    when 'console'
      hosts.take(1).each do |host|
        `ttab ey console -e #{environment} -c pikock` 
      end
    when 'htop'
      `ttab ey ssh "/usr/bin/htop" -t --app-servers -e #{environment} -c pikock` 
    when 'ssh'
      hosts.each do |host|
        `ttab ssh deploy@#{host} "cd /data/ecosystemgold/current"`
      end
    when 'logs'
      case @instance_type
      when 'thumbs'
        hosts.each do |host|
          `ttab ssh deploy@#{host} "tail -f /data/ecosystemgold/current/log/thumb_generator.log"`
        end
      when 'apps'
        hosts.each do |host|
          `ttab ssh deploy@#{host} "tail -f /data/ecosystemgold/current/log/production.log"`
        end
      when 'sites'
        hosts.each do |host|
          `ttab ssh deploy@#{host} "tail -f /data/ecosystemgold/current/log/background_jobs.log"`
        end
      when 'images'
        hosts.each do |host|
          `ttab ssh deploy@#{host} "tail -f /data/ecosystemgold/current/log/image_processor.log"`
        end
      end
    end
  end
end

Koko.new(ARGV)
