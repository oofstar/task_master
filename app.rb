require 'sinatra'
require 'json'
require 'pry'
require 'dotenv'
require 'httparty'

Dotenv.load

get '/' do
  'Hello world!'
end

# when a direct message(message.im) is sent to the app, slack posts to /tasky
post '/tasky' do

  # parse request data
  request_data = JSON.parse(request.body.read)
  case request_data['type']

    # required response when slack performs url verification
    when 'url_verification'
      request_data['challenge']

    # type of request created by message.im Events api call
    when 'event_callback'
      # trim down request to necessary event data
      event_data = request_data["event"]

      # script should only run if direct message was not initiated by a bot
      if !event_data["bot_id"]
        puts "it's an event"
        # tasker variable is set to user who sent message
        tasker = event_data["user"]

        # taskee is user being assigned to task. this block is parsing taskee and task from text sent by tasker
        task_arr = event_data["text"].split
        taskee = task_arr.shift
        task = task_arr.join(' ')

        # console logs for troubleshooting
        puts "tasker: #{tasker}"
        puts "taskee: #{taskee}"
        puts "task: #{task}"

        # call to Web API to determine correct channel id for DM to taskee
        taskee_response = JSON.parse(HTTParty.post("https://slack.com/api/im.open",
          body: {
            "token" => ENV['SLACK_API_TOKEN'],
            "user" => "#{taskee.delete('<' '@' '>')}"
          },
          headers: { 'Content-Type' => 'application/x-www-form-urlencoded' }
        ).to_s)

        taskee_channel = taskee_response["channel"]["id"]

        # Web API call to send message to taskee notifying them of task assignment
        HTTParty.post("https://slack.com/api/chat.postMessage",
           body:  {
              "token" => ENV['SLACK_API_TOKEN'],
              "text": "<@#{tasker}> has asked you to #{task}",
              "channel" => "#{taskee_channel}",
              "username" => "Tasky",
              "as_user" => "false"
            },
         :headers => { 'Content-Type' => 'application/x-www-form-urlencoded' }
        )

        # call to Web API to determine correct channel id for DM to tasker. channel from original request is not the same
        tasker_response = JSON.parse(HTTParty.post("https://slack.com/api/im.open",
          body: {
            "token" => ENV['SLACK_API_TOKEN'],
            "user" => "#{tasker}"
          },
          headers: { 'Content-Type' => 'application/x-www-form-urlencoded' }
        ).to_s)

        tasker_channel = tasker_response["channel"]["id"]

        # Web API call to send message to tasker notifying them task was assigned
        HTTParty.post("https://slack.com/api/chat.postMessage",
           body:  {
              "token" => ENV['SLACK_API_TOKEN'],
              "text" => "#{task} assigned to #{taskee}.",
              "channel" => "#{tasker_channel}",
              "username" => "Tasky",
              "as_user" => "false"
            },
         :headers => { 'Content-Type' => 'application/x-www-form-urlencoded' }
       )

     end
  end

end

# When button is clicked re: task completion, Slack posts to /button
# post '/button' do
#   request_data = JSON.parse(request.params["payload"])
#   "got it!"
# end
