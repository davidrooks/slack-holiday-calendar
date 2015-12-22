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

post '/test' do
  params = eval(request.body.read)
  halt 200, 'Holidays = ' + @holidays
end

get '/test' do
  halt 200, 'Holidays = ' + @holidays
end


post '/' do
  if params['text']
    puts 'found text param'
    commands = params['text'].split
    if commands.size != 0
      if @holidays.has_key? commands[0]
        if !@holidays[commands[0]].include? commands[1]
          @holidays[commands[0]] << commands[1]
        end
      else
        @holidays[commands[0]] = []
        @holidays[commands[0]] << commands[1]
      end
    end
  end

  showHolidays
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
      ret =  name.to_s + ' '
    end
  end
  if ret == ''
    ret = 'none booked'
  end
  return ret
end


after do
  @res[:json] = @holidays.to_json
  @res.save
end


