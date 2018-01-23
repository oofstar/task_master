require 'sinatra'
require 'json'
require 'pry'

get '/' do
  'Hello world!'
end

post '/tasky' do
  request_data = JSON.parse(request.body.read)
  case request_data['type']
    when 'url_verification'
      request_data['challenge']

    when 'event_callback'
      puts "it's an event"
      event_data = request_data["event"]
      tasker = event_data["user"]

      task_arr = event_data["text"].split
      taskee = task_arr.shift.delete('<' '@' '>')
      task = task_arr.join(' ')
      puts "tasker: #{tasker}"
      puts "taskee: #{taskee}"
      puts "task: #{task}"

  end
end



# {"type"=>"message",
#  "user"=>"U8WKR3K2Q",
#  "text"=>"<@U8WKR3K2Q> buy pizza",
#  "ts"=>"1516743130.000013",
#  "channel"=>"D8WNCB1UY",
#  "event_ts"=>"1516743130.000013"}
