require 'yaml'
require 'pdf-reader'
require 'time'

class RegattaTweet
  include Enumerable

  def self.abbreviations
    @abbreviations ||= YAML.load_file 'abbreviations.yml'
  end
  def abbreviations; self.class.abbreviations; end

  attr_accessor :reader
  def initialize(pdf_filename)
    self.reader = PDF::Reader.new pdf_filename
  end

  def each(&block)
    self.tweets.each &block
  end

  def tweets
    return @tweets if defined?(@tweets)

    raw_strings = reader.pages.map do |page|
      page_strings = []
      saved = nil
      page.raw_content.scan(/\(((?:\\.|(?<!\\).)*)\)/).flatten.map{|_|_.gsub("\\t",' ').squeeze(' ')}.each do |string|
        # deal with long entry name that splits the name between \( and \) onto a 2nd line
        if string =~ /\\\(/ && string !~ /\\\)/
          saved = string
          next
        elsif saved && string !~ /\\\(/ && string =~ /\\\)/
          string = saved << string
          saved = nil
        end
        page_strings << string
      end
      page_strings
    end.flatten.map {|_|_.gsub(/ ?\\\(.*\\\)(?: *[AB]+)?\z/,'')}.map{|_|_.gsub(/\\([()]) ?/,'\1')}

    # This might not be needed now that page breaks are handled before the replacements
    created_at = Time.parse reader.info[:CreationDate][2..-8]
    subject = reader.info[:Subject]
    abbreviations.unshift({pdf: [{created_at.strftime('%A %d-%b-%Y') => ''},
                                 {'Page:' => ''},
                                 {subject => ''},
                                ]})

    # Prep to handle page number eliding
    page_str = Regexp.new("#{created_at.strftime('%A %d-%b-%Y')} Page:")
    delete_next = nil

    shortened = raw_strings.map do |string|
      if page_str =~ string         # Oh, the page number is next!
        delete_next = true          # We don't want it.
        ''                          # (blanks will disappear)
      elsif delete_next             # This is the page number
        delete_next = nil           # back to your regularly scheduled programming
        ''
      else                          # something we want to boild down a bit
        puts "#{string.inspect} => " if $DEBUG
        abbreviations.each do |set|
          set.each do |group, list|
            list.each do |pair| pair.each do |original,replacement|
                blurb = "   #{original.inspect} => #{replacement.inspect} :: "
                if string.gsub!(original, replacement)
                  puts "#{blurb} #{string.inspect}" if $DEBUG
                end
              end; end
          end
        end
        string.squeeze(' ').strip
      end
    end.delete_if {|_|_.empty? || _ =~ /protest/i} # Hopfully, any note has 'protest' if race is unofficial

    # Take the concentrated raw data and make tweet-sized strings
    @tweets = []
    resyncing = false
    shortened.each_slice(4) do |place,entry,lane,time|
      case time
      when 'Unofficial'
        resyncing = true
        next
      when 'Official','Upcoming'
        resyncing = false
        race, starts, event, status = place, entry, lane, time
        event.gsub!(/\A *0 */,'')
        puts "Race: #{race} Starts: #{starts} Event: #{event} Status: #{status}" if $DEBUG
        sep = event =~ /\A\w/ ? ' ' : ''
        @tweets << ["#{race}#{sep}#{event}"]
      when 'Time'                   # Oh, no need for headings.
        nil
      else
        next if resyncing
        time.gsub!(/\A0*([1-9][0-9]?:[0-5][0-9]\.[0-9])[0-9 ]*\z/,'\1')
        puts "#{place} #{entry} #{time}" if $DEBUG
        @tweets[-1] << "#{place}-#{entry} #{time}"
      end
    end

    @tweets = @tweets.map do |tweet|
      tweet.join("; ") if tweet.size > 1
    end.compact

    @tweets.each do |tweet|
      puts "%3d%s %s\033[01;31m%s\033[0m"%[tweet.length, tweet.length > 140 ? "\033[32m>" : ':',
                                           tweet[0,140], tweet[140..-1]]
    end if $DEBUG
    @tweets
  end
end


if $0 == __FILE__
  rt = RegattaTweet.new(ARGV.shift || "/Users/rab/Downloads/results\ \(26\).pdf")
  rt.each {|tweet| puts tweet }
  puts rt.map(&:length).max
end
