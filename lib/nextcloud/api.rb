module Nextcloud
  class Api
    # Bound every request so a hung Nextcloud instance cannot pin the calling
    # thread on Net::HTTP's 60s defaults. read/write are per-idle-read timeouts
    # (they reset on each chunk), so 30s does not cap total transfer time for
    # large downloads/uploads — it only trips a genuinely stalled connection.
    OPEN_TIMEOUT  = 5
    READ_TIMEOUT  = 30
    WRITE_TIMEOUT = 30

    attr_reader :url, :username, :password
    protected :url
    protected :username
    protected :password

    # Gathers credentials for communicating with Nextcloud instance
    #
    # @param [Hash] args authentication credentials.
    # @option args [String] :url Nextcloud instance URL
    # @option args [String] :username Nextcloud instance administrator username
    # @option args [String] :password Nextcloud instance administrator password
    def initialize(args)
      @url = URI(args[:url] + "/iqidrive/ocs/v2.php/cloud/")
      @username = args[:username]
      @password = args[:password]
    end

    # Sends API request to Nextcloud
    #
    # @param method [Symbol] Request type. Can be :get, :post, :put, etc.
    # @param path [String] Nextcloud OCS API request path
    # @param params [Hash, nil] Parameters to send
    # @return [Object] Nokogiri::XML::Document
    def request(method, path, params = nil, body = nil, depth = nil, destination = nil, raw = false)
      response = Net::HTTP.start(@url.host, @url.port,
        use_ssl: @url.scheme == "https",
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT,
        write_timeout: WRITE_TIMEOUT) do |http|
        req = Kernel.const_get("Net::HTTP::#{method.capitalize}").new(@url.request_uri + path)
        req["OCS-APIRequest"] = true
        req.basic_auth @username, @password
        req["Content-Type"] = "application/x-www-form-urlencoded"

        req["Depth"] = 0 if depth
        req["Destination"] = destination if destination

        req.set_form_data(params) if params
        req.body = body if body

        http.request(req)
      end

      # if ![201, 204, 207].include? response.code
      #   raise Errors::Error.new("Nextcloud received invalid status code")
      # end
      raw ? response.body : Nokogiri::XML.parse(response.body)
    end

    # Creates Ocs API instance
    #
    # @return [Object] OcsApi
    def ocs
      OcsApi.new(url: @url, username: @username, password: @password)
    end

    # Create WebDav API instance
    #
    # @return [Object] WebdavApi
    def webdav
      WebdavApi.new(url: @url, username: @username, password: @password)
    end
  end
end
