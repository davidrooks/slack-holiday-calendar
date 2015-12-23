require 'sinatra/activerecord'
require 'sinatra'
require 'json'
require 'date'

env = ENV['ENVIRONMENT'] || 'DEVELOP'

set :database, {adapter: "sqlite3", database: "holiday_calendar.sqlite3"}


ActiveRecord::Schema.define do
  if !ActiveRecord::Base.connection.tables.include? 'holidays'
    create_table :holidays do |t|
      t.column :json, :string
    end
  end
end

class Holiday < ActiveRecord::Base
end

before do
  @res = Holiday.all
  if @res.count == 0
    @res = Holiday.create(:json => {})
  else
    @res = @res.first
  end

  @holidays = eval(@res[:json])
end

get '/test' do
  halt 200, @holidays.to_s
end


post '/' do
  if params['text']
    commands = params['text'].split
    if commands.size >= 2
      slack_name = commands[0]
      holiday_date = commands[1]
      if !slack_name.start_with? '@'
        showUsage
      end
      begin
        Date.parse(holiday_date)
      rescue ArgumentError
        showUsage
      end
      if commands.size == 2
        addHoliday(slack_name.to_sym, holiday_date)
      end
      if commands.size == 4 && commands[2].upcase == 'TO'
        holiday_date_end = commands[3]
        begin
          Date.parse(holiday_date_end)
        rescue ArgumentError
          showUsage
        end
        addHoliday(slack_name.to_sym, holiday_date, holiday_date_end)
      end

    end
  end

  showHolidays
end

def addHoliday(name, start_date, end_date=NIL) 
  if end_date.nil? 
    end_date=start_date
  end

  if !@holidays.has_key? name
    @holidays[name] = []
  end

  Date.parse(start_date).upto(Date.parse(end_date)) do |date|
    puts 'adding ' + date.strftime('%d-%m-%Y')
    if !@holidays[name].include? date.strftime('%d-%m-%Y')
      @holidays[name] << date.strftime('%d-%m-%Y')
    end
  end
end

def showUsage
  res = {}
  res['title'] = 'Holidays'
  res['text'] = '*USAGE*\nTo view the upcoming holidays calendar just type /holidays\n
  To add a date to the calendar type /holidays [@name] [dd-mm-yyyy]   E.G. /holidays @john 25-12-2016\n'
  halt 200, {'Content-Type' => 'application/json'}, res.to_json
end

def showHolidays
  res = {}
  if ENV['SEND_TO'] && ENV['SEND_TO'].upcase == 'ALL'
    res["response_type"] = "in_channel"
  end
  res["title"] = "Holidays"
  tmp = ''


  Date.today.upto(Date.today+14.days) do |date|
    tmp = tmp + '*' + date.strftime('%d-%m-%Y') + '* -- ' + checkDate(date.strftime('%d-%m-%Y')) + '\n'
  end

  res["text"] = tmp
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
  @holidays.each {|k,v| @holidays[k] = v.reject{|x| Date.parse(x) < Date.today}}
  @res[:json] = @holidays.to_json
  @res.save
end


