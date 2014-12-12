require "optimus_connector/version"
require "optimus_connector/transaction_watcher"
require "optimus_connector/server_watcher"

module OptimusConnector
  def self.new(*args)
    config = YAML::load(File.open("#{Rails.root}/config/optimus_connector.yml"))[Rails.env]
    TransactionWatcher.new(config) if config["monitor_transactions"]
    ServerWatcher.new(config) if config["monitor_server"]
  end

  def self.default_config
    {
        api_url: "http://www.optimus_app_url_goes_here.com",
        filter_sql_queries: true,
        monitor_server: true
    }
  end
end