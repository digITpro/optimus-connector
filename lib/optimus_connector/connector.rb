require "optimus_connector/logger"

module OptimusConnector
  class Connector

    def initialize(config)
      @config = config
    end

    def post(path, data)
      data.merge!(api_key: @config["api_key"], app_name: @config["application_name"], environment_name: Rails.env)
      uri = URI.parse(@config["api_url"] + path)
      Net::HTTP.start(uri.host, uri.port) do |http|
        post = Net::HTTP::Post.new(uri.path)
        post.content_type = "application/json"
        post.body = data.to_json
        http.request(post)
      end
    rescue => exception
      Logger.log(exception)
    end
  end
end