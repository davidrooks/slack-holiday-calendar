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

WARNINGS = 3

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
    if commands.size == 2
      slack_name = commands[0]
      holiday_date = commands[1]
      # if !name.start_with? '@'
      #   showUsage
      # end
      # if !
      addHoliday(slack_name.to_sym, holiday_date)
    end
  end

  showHolidays
end

def addHoliday(name, date) 
  puts @holidays.to_s
  if @holidays.has_key? name
    puts 'key exists'
    if !@holidays[name].include? date
      @holidays[name] << date
    end
  else
    puts 'new key'
    @holidays[name] = []
    @holidays[name] << date
  end
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
  @holidays.each {|k,v| @holidays[k] = v.reject{|x| Date.strptime(x,'%d-%m-%Y')<Date.today}}
  @res[:json] = @holidays.to_json
  @res.save
end


