require 'rubygems'
require 'bundler/setup'

require './regatta_tweet'

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
