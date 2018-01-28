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

      # script should only run if direct message was not initiated by a bot and if event wasn't actually changing of message.
      if !event_data["bot_id"] && !event_data["previous_message"]
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
            "token": ENV['SLACK_API_TOKEN'],
            "user": "#{taskee.delete('<' '@' '>')}"
          },
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
        ).to_s)

        taskee_channel = taskee_response["channel"]["id"]

        # Web API call to send message to taskee notifying them of task assignment
        HTTParty.post("https://slack.com/api/chat.postMessage",
           body:  {
              "token": ENV['SLACK_API_TOKEN'],
              "text": "<@#{tasker}> has asked you to #{task}",
              "attachments": [
                {
                  "text": "Have you completed #{task}?",
                  "fallback": "Have you completed #{task}?",
                  "callback_id": "completion",
                  "color": "#3AA3E3",
                  "attachment_type": "default",
                  "actions": [
                    {
                      "name": "completed",
                      "text": "Task Completed",
                      "type": "button",
                      "value": "completed"
                    },
                    {
                      "name": "incomplete",
                      "text": "Cannot Complete Task",
                      "type": "button",
                      "value": "incomplete"
                    }
                  ]
                }
              ].to_json,

              "channel": "#{taskee_channel}",
              "username": "Tasky",
              "as_user": "false"
            },
         headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
        )

        # call to Web API to determine correct channel id for DM to tasker. channel from original request is not the same
        tasker_response = JSON.parse(HTTParty.post("https://slack.com/api/im.open",
          body: {
            "token": ENV['SLACK_API_TOKEN'],
            "user": "#{tasker}"
          },
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
        ).to_s)

        tasker_channel = tasker_response["channel"]["id"]

        # Web API call to send message to tasker notifying them task was assigned
        HTTParty.post("https://slack.com/api/chat.postMessage",
           body:  {
              "token": ENV['SLACK_API_TOKEN'],
              "text": "Task Sent!",
              "attachments": [
                {
                  "text": "#{task} assigned to #{taskee}.",
                  "fallback": "#{task} assigned to #{taskee}.",
                  "callback_id": "completion",
                  "color": "#3AA3E3",
                  "attachment_type": "default",
                }
              ].to_json,
              "channel": "#{tasker_channel}",
              "username": "Tasky",
              "as_user": "false"
            },
         headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
       )
     end

  end

end

# when button is pressed, slack posts to /button
post '/button' do
  # binding.pry
  # parse payload from slack
  payload = JSON.parse(request["payload"])

  # original message is used to get tasker ID and task text
  original_message = payload["original_message"]["text"].sub(" has asked you to", "")
  taskee = payload["user"]["id"]
  task_arr = original_message.split
  tasker = task_arr.shift
  task = task_arr.join(' ')

  # im.open request sent to slack to determine correct channel id for tasker
  tasker_response = JSON.parse(HTTParty.post("https://slack.com/api/im.open",
    body: {
      "token": ENV['SLACK_API_TOKEN'],
      "user": "#{tasker.delete('<' '@' '>')}"
    },
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
  ).to_s)

  tasker_channel = tasker_response["channel"]["id"]

  case payload["actions"][0]["value"]
    # if button is pressed for task completion, variables set here:
    when "completed"
      completion = "Task Complete!"
      task_answer = "<@#{taskee}> has completed the task you assigned: #{task}."
      puts "task was completed"
      color = "#79A687"
      message = "Completion confirmation sent to #{tasker}."
    # if button is pressed that task cannot be completed, variables set here:
    when "incomplete"
      completion = "Task Cannot Be Completed!"
      task_answer = "<@#{taskee}> cannot complete the task you assigned: #{task}"
      puts "task cannot be completed"
      color = "#ff0000"
      message = "Rejection of task as not completable sent to #{tasker}."
  end

  # confirmation or rejection message sent to tasker
  HTTParty.post("https://slack.com/api/chat.postMessage",
     body: {
        "token": ENV['SLACK_API_TOKEN'],
        "text": completion,
        "attachments": [
          {
            "text": task_answer,
            "fallback": task_answer,
            "callback_id": "completion",
            "color": color,
            "attachment_type": "default",
          }
        ].to_json,
        "channel": "#{tasker_channel}",
        "username": "Tasky",
        "as_user": "false"
      },
   headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
  )
  # return value replaces message in taskees DM channel
  message
end
