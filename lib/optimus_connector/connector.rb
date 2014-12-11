module OptimusConnector
  class Connector

    def initialize(config)
      @config = config
    end

    def post(path, data)
      uri = URI(@config[:api_url] + path)
      Net::HTTP.start(uri.host, uri.port) do |http|
        post = Net::HTTP::Post.new(uri.path)
        post.content_type = "application/json"
        post.basic_auth(@config[:app_id], @config[:api_key])
        post.body = data.to_json
        Rails.logger.error("[optimus_connector] " + post.body)
        http.request(post)
      end
    rescue => exception
      log_error(exception)
    end
  end
end