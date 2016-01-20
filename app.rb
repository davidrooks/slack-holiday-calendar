require 'sinatra/base'
require 'json'
require 'date'
# require 'rest-client'
require 'google/apis/calendar_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'openssl'
require 'fileutils'

class App < Sinatra::Base

  JSON_API = 'https://api.myjson.com/bins/4apkb'
  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
  APPLICATION_NAME = 'Google Calendar API Ruby Quickstart'
  CLIENT_SECRETS_PATH = 'client_secret.json'
  CREDENTIALS_PATH = File.join(Dir.home, '.credentials',
                               "calendar-ruby-quickstart.yaml")
  SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY

  # configure :production, :development do
  #   if ENV['VCAP_SERVICES']
  #     vcap = "http://#{ENV['WEB_PROXY_USER']}:#{ENV['WEB_PROXY_PASS']}@#{ENV['WEB_PROXY_HOST']}:#{ENV['WEB_PROXY_PORT']}"
  #     RestClient.proxy = vcap
  #   end
  # end


  post '/' do
    getHolidays
    showHolidays
  end

  def showHolidays
    res = {}
    if ENV['SEND_TO'] && ENV['SEND_TO'].upcase == 'ALL'
      res['response_type'] = 'in_channel'
    end
    res['title'] = 'Holidays'
    res['attachments'] = []

    Date.today.upto(Date.today+14) do |date|
      tmp = {}
      tmp['title'] = date.strftime('%d-%m-%Y')
      tmp['text'] = checkDate(date.strftime('%d-%m-%Y'))
      if date.saturday? || date.sunday?
        tmp['color'] = 'warn'
      else
        tmp['color'] = 'good'
      end

      res['attachments'] << tmp
    end

    res['mrkdwn'] = true

    halt 200, {'Content-Type' => 'application/json'}, res.to_json
  end

  def getHolidays
    service = Google::Apis::CalendarV3::CalendarService.new
    service.client_options.application_name = APPLICATION_NAME
    service.authorization = authorize

# Fetch the next 10 events for the user
    calendar_id = 'primary'
    response = service.list_events(calendar_id,
                                   max_results: 10,
                                   single_events: true,
                                   order_by: 'startTime',
                                   time_min: Time.now.iso8601)

    puts "Upcoming events:"
    puts "No upcoming events found" if response.items.empty?
    @holidays = {}
    response.items.each do |event|
      start_date = event.start.date
      end_date = event.end.date
      puts "- #{event.summary} (#{start_date}) - (#{end_date})"

      if !@holidays.has_key? event.summary
        @holidays[event.summary] = []
      end

      Date.parse(start_date).upto(Date.parse(end_date)) do |date|
        if !@holidays[event.summary].include? date.strftime('%d-%m-%Y')
          @holidays[event.summary] << date.strftime('%d-%m-%Y')
        end
      end
    end
  end

  def authorize
    FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

    client_id = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: CREDENTIALS_PATH)
    authorizer = Google::Auth::UserAuthorizer.new(
        client_id, SCOPE, token_store)
    user_id = 'default'
    credentials = authorizer.get_credentials(user_id)
    if credentials.nil?
      url = authorizer.get_authorization_url(
          base_url: OOB_URI)
      puts "Open the following URL in the browser and enter the " +
               "resulting code after authorization"
      puts url
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(
          user_id: user_id, code: code, base_url: OOB_URI)
    end
    credentials
  end



  def checkDate(date)
    ret = ''
    @holidays.keys.each do |name|
      if (@holidays[name].include? date.to_s) then
        ret =  ret + name.to_s + ' '
      end
    end
    if ret == ''
      ret = 'none booked'
    end
    return ret
  end

end
