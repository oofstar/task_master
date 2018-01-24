require 'sinatra'
require 'json'
require 'pry'
require 'dotenv'
require 'httparty'

Dotenv.load

get '/' do
  'Hello world!'
end

post '/tasky' do
  request_data = JSON.parse(request.body.read)
  puts request_data
  case request_data['type']
    when 'url_verification'
      request_data['challenge']

    when 'event_callback'

      event_data = request_data["event"]
      # binding.pry
      if !event_data["bot_id"]
        puts "it's an event"
        tasker = event_data["user"]

        task_arr = event_data["text"].split
        taskee = task_arr.shift
        task = task_arr.join(' ')

        puts "tasker: #{tasker}"
        puts "taskee: #{taskee}"
        puts "task: #{task}"




        response = JSON.parse(HTTParty.post("https://slack.com/api/im.open",
          body: {
            "token" => ENV['SLACK_API_TOKEN'],
            "user" => "#{tasker}"
          },
          headers: { 'Content-Type' => 'application/x-www-form-urlencoded' }
        ).to_s)

        channel = response["channel"]["id"]


        HTTParty.post("https://slack.com/api/chat.postMessage",
           body:  {
              "token" => ENV['SLACK_API_TOKEN'],
              "text" => "#{task} assigned to #{taskee}",
              "channel" => "#{channel}",
              "username" => "Tasky",
              "as_user" => "false"
            },
         :headers => { 'Content-Type' => 'application/x-www-form-urlencoded' }
       )

     end


  end
end
