require 'rubygems'
require 'bundler/setup'

require './regatta_tweet'

# Expect to find these configuration values in the environment:
#   TWITTER_CONSUMER_KEY
#   TWITTER_CONSUMER_SECRET
#   TWITTER_OAUTH_TOKEN
#   TWITTER_OAUTH_TOKEN_SECRET
unless ENV['TWITTER_CONSUMER_KEY']
  if File.exist?('.env')
    File.foreach('.env') do |line|
      name, value = line.split('=', 2)
      ENV[name] = value
    end
  end
end

require 'twitter'

ARGV.each do |file|
  rt = RegattaTweet.new(file)
  rt.each do |tweet|
    Twitter.update tweet
    # puts "I would say: #{tweet}"
  end
end
