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
    if commands.size >= 3
      command = commands[0].upcase
      slack_name = commands[1]
      holiday_date = commands[2]
      
      
      if commands.size == 3 
        if command == 'ADD'
          addHoliday(slack_name.to_sym, holiday_date)        
        elsif command == 'REMOVE'
          deleteHoliday(slack_name.to_sym, holiday_date)        
        end            
      end

      if commands.size == 5 && commands[3].upcase == 'TO'
        holiday_date_end = commands[4]
        validateParams slack_name, holiday_date, holiday_date_end
        if command == 'ADD'
          addHoliday(slack_name.to_sym, holiday_date, holiday_date_end)
        elsif command == 'REMOVE'
          deleteHoliday(slack_name.to_sym, holiday_date, holiday_date_end)
        end
      end      
    end
  end
  showHolidays
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

  if @holidays.has_key? name
    Date.parse(start_date).upto(Date.parse(end_date)) do |date|    
      @holidays[name].delete(date.strftime('%d-%m-%Y'))        
    end
  end
end


def showUsage
  res = {}
  res['title'] = 'Holidays'
  res['text'] = '*USAGE*\nTo view the upcoming holidays calendar just type /holidays\n
  To add a date to the calendar type /holidays add [@name] [dd-mm-yyyy]   E.G. /holidays @john 25-12-2016\n
  To add a rangeof dates type /holidays add [@name] [dd-mm-yyyy] to [dd-mm-yyyy]   E.G. /holidays @john 22-12-2015 to 03-01-2016\n
  To delete a date from the calendar type /holidays remove [@name] [dd-mm-yyyy]   E.G. /holidays remove @john 25-12-2016\n
  To delete a rangeof dates type /holidays add remove [@name] [dd-mm-yyyy] to [dd-mm-yyyy]   E.G. /holidays remove @john 22-12-2015 to 03-01-2016\n'
  halt 200, {'Content-Type' => 'application/json'}, res.to_json
end

def showHolidays
  res = {}
  if ENV['SEND_TO'] && ENV['SEND_TO'].upcase == 'ALL'
    res["response_type"] = "in_channel"
  end
  res["title"] = "Holidays"
  res['attachments'] = []
  


  Date.today.upto(Date.today+14.days) do |date|
    tmp = {}
    tmp['title'] = date.strftime('%d-%m-%Y') 
    tmp['text'] = checkDate(date.strftime('%d-%m-%Y'))
    tmp['color'] = 'good'
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
  @holidays.each {|k,v| @holidays[k] = v.reject{|x| Date.parse(x) < Date.today}}
  @res[:json] = @holidays.to_json
  @res.save
end


