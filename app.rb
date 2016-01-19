require 'sinatra/base'
require 'json'
require 'date'
require 'rest-client'

class App < Sinatra::Base

  JSON_API = 'https://api.myjson.com/bins/4apkb'

  configure :production, :development do
    enable :logging
    if ENV['VCAP_SERVICES']
      vcap = "http://#{ENV['WEB_PROXY_USER']}:#{ENV['WEB_PROXY_PASS']}@#{ENV['WEB_PROXY_HOST']}:#{ENV['WEB_PROXY_PORT']}"
      RestClient.proxy = vcap
    end
  end

  before do
    next unless request.post?
    res = JSON.parse(RestClient.get JSON_API, {:accept => :json})

    @holidays = res.to_hash
  end

  post '/' do
    showHolidays
  end

  post '/add' do
    slack_name = params['name']
    holiday_date = params['start_date']
    params['end_date'].nil? ? holiday_date_end = NIL : holiday_date_end = params['end_date']

    validateParams slack_name, holiday_date, holiday_date_end

    addHoliday(slack_name.to_sym, holiday_date, holiday_date_end)
  end

  post '/delete' do
    slack_name = params['name']
    holiday_date = params['start_date']
    params['end_date'].nil? ? holiday_date_end = NIL : holiday_date_end = params['end_date']

    validateParams slack_name, holiday_date, holiday_date_end
    puts 'deleting holiday'
    deleteHoliday(slack_name.to_sym, holiday_date, holiday_date_end)
  end

  def validateParams(slack_name, start_date, end_date=NIL)
    if !slack_name.start_with? '@'
      showUsage
    end
    begin
      Date.parse(start_date)
      Date.parse(end_date) unless end_date.nil?
    rescue ArgumentError
      showUsage
    end
  end


  def addHoliday(name, start_date, end_date=NIL)
    if end_date.nil?
      end_date=start_date
    end

    if !@holidays.has_key? name
      @holidays[name] = []
    end

    Date.parse(start_date).upto(Date.parse(end_date)) do |date|
      if !@holidays[name].include? date.strftime('%d-%m-%Y')
        @holidays[name] << date.strftime('%d-%m-%Y')
      end
    end
  end

  def deleteHoliday(name, start_date, end_date=NIL)
    if end_date.nil?
      end_date=start_date
    end

    puts @holidays.to_s
    puts name
    puts start_date
    puts end_date
    if @holidays.has_key? name.to_s
      puts 'has key'
      Date.parse(start_date).upto(Date.parse(end_date)) do |date|
        puts 'deleting - ' + date.to_s
        puts @holidays.to_s
        @holidays[name.to_s].delete(date.strftime('%d-%m-%Y'))
      end
    end
  end


  def showUsage
    res = {}
    res['title'] = 'Holidays'
    res['text'] = '*USAGE*\nTo view the upcoming holidays calendar just type /holidays'
    halt 200, {'Content-Type' => 'application/json'}, res.to_json
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


  after do
    next unless request.post?

    @holidays.each {|k,v| @holidays[k] = v.reject{|x| Date.parse(x) < Date.today}}
    RestClient.put JSON_API, @holidays.to_json, :content_type => 'application/json'
  end

end
