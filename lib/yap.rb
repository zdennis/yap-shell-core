require "term/ansicolor"
require "tins"
require "byebug"
require "pry"
require "treefell"
require 'optparse'

module Yap
  require 'yap/configuration'
  require 'yap/shell'
  require 'yap/world'

  def self.parse_cli_args_for_configuration(args, configuration)
    OptionParser.new do |opts|
      opts.on('-h', '--help', 'Prints this help') do
        puts opts
        exit
      end

      opts.on('--skip-first-time', 'Disables creating ~/.yap directory on shell startup') do
        configuration.skip_first_time = true
      end

      opts.on('--no-addons', 'Disables auto-loading addons on shell startup') do
        configuration.use_addons = false
      end

      opts.on('--no-history', 'Disables auto-loading or saving history') do
        configuration.use_history = false
      end

      opts.on('--no-rcfiles', 'Disables auto-loading rcfiles on shell startup') do
        configuration.use_rcfiles = false
      end
    end.parse!(args)
  end

  def self.run_shell(argv)
    Treefell['shell'].puts "#{self}.#{__callee__} booting shell"

    parse_cli_args_for_configuration(argv, configuration)

    addons_loaded = []
    if configuration.use_addons?
      Treefell['shell'].puts "#{self}.#{__callee__} loading addons"
      addons_loaded.concat \
        World::Addons.load_directories(configuration.addon_paths)
    else
      Treefell['shell'].puts "#{self}.#{__callee__} skipping addons"
    end

    if configuration.use_rcfiles?
      Treefell['shell'].puts "#{self}.#{__callee__} loading rcfiles"
      addons_loaded.concat \
        World::Addons.load_rcfiles(configuration.rcfiles)
    else
      Treefell['shell'].puts "#{self}.#{__callee__} skipping rcfiles"
    end

    Shell::Impl.new(addons: addons_loaded).repl
  end
end
