require "optimus_connector/version"
require "optimus_connector/transaction_watcher"
require "optimus_connector/server_watcher"

module OptimusConnector
  class Railtie < Rails::Railtie
    initializer "optimus_connector.start_plugin" do
      OptimusConnector.start
    end
  end

  class OptimusConnector
    def self.start
      TransactionWatcher.new
      ServerWatcher.new
    end

    def self.connector
      @connector ||= Connector.new(config)
    end

    def self.config
      @config ||= YAML::load(File.open("#{Rails.root}/config/optimus_connector.yml"))[Rails.env]
      @config.merge!(api_url: "http://optimus.digitpro.ch")
      @config.with_indifferent_access
    end
  end
end