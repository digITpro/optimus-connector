require "optimus_connector/version"
require "optimus_connector/transaction_watcher"
require "optimus_connector/server_watcher"

module OptimusConnector
  def self.new(*args)
    config = self.default_config.merge(*args)
    TransactionWatcher.new(config)
    ServerWatcher.new(config) if config[:monitor_server]
  end

  def self.default_config
    {
        api_url: "http://www.optimus_app_url_goes_here.com",
        app_relevant_sql_only: true,
        monitor_server: true
    }
  end
end