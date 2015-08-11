module Lita
  module Handlers
    class GithubPinger < Handler

      config :engineers, type: Array, required: true

      http.post("/ghping", :ghping)

      def ghping(request, response)
        body = MultiJson.load(request.body)

        if body["comment"]
          thing     = body["pull_request"] || body["issue"]
          pr_url    = thing["html_url"]
          comment   = body["comment"]["body"]
          commenter = body["comment"]["user"]["login"]

          # automatically include the creator of the PR
          usernames_to_ping = [thing["user"]["login"]]

          # Is anyone mentioned in this comment?
          if comment.include?("@")
            # get each @mentioned username in the comment
            mentions = comment.split("@")[1..-1].map { |snip| snip.split(" ").first }

            # add them to the list of usernames to ping
            usernames_to_ping = usernames_to_ping.concat(mentions).uniq

            # slackify all of the users
            usernames_to_ping.map! { |user| github_username_to_slack_username(user) }
          end

          message  = "New PR comment from #{commenter}:\n"
          message += "#{pr_url}\n#{comment}"

          puts "Got a comment on something, sending messages to #{usernames_to_ping}"

          usernames_to_ping.each { |user| send_dm(user, message) }
        end

        response
      end

      def alert_eng_pr(message)
        room = Lita::Room.fuzzy_find("eng")
        source = Lita::Source.new(room: room)
        robot.send_message(source, message)
      end

      def github_username_to_slack_username(github_username)
        config.engineers.select do |eng|
          eng[:github] == github_username
        end.first[:slack]
      end

      def send_dm(username, content)
        if user = Lita::User.fuzzy_find(username)
          source = Lita::Source.new(user: user)
          robot.send_message(source, content)
        else
          puts "Could not find user with name #{username}"
        end
      end
    end

    Lita.register_handler(GithubPinger)
  end
end
