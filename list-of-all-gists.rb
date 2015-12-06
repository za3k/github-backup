require 'yajl'
require 'log4r'
require 'http'

@log = Log4r::Logger.new('github')
@log.add(Log4r::StdoutOutputter.new('console', {
  :formatter => Log4r::PatternFormatter.new(:pattern => "[#{Process.pid}:%l] %d :: %m")
}))

stop = Proc.new do
  puts "Terminating crawler"
  exit(1)
end

Signal.trap("INT",  &stop)
Signal.trap("TERM", &stop)

@latest = []
@latest_key = lambda { |e| "#{e['id']}" }
@last_seen = (Time.at 1).iso8601 # Unix epoch
unless ARGV.empty?
  @last_seen = ARGV.shift.to_i
end

while true
  url = "https://api.github.com/gists/public?since=#{@last_seen}"
  @log.info url
  response = HTTP.headers('user-agent' => 'github-user:za3k',
      'Authorization' => 'token ' + ENV['GITHUB_TOKEN'])
            .accept(:json)
            .timeout(:connect => 5, :read => 5)
            .get("https://api.github.com/gists/public?since=#{@last_seen}")
  

  if response.code >= 300
    @log.error "Error: #{response.code} #{response.reason}, \
                header: #{response.headers}, \
                response: #{response.body}"
  else
    begin
      latest = Yajl::Parser.parse(response.to_s)
      ids = latest.collect(&@latest_key)
      new_gists = latest.reject { |e| @latest.include? @latest_key.call(e) }
     
      @latest = ids
      new_gists.sort_by { |e| [Time.parse(e['created_at']), e['id']] }.each do |gist|
        timestamp = Time.parse(gist['created_at']).strftime('%Y-%m-%d-%-k')
        archive = "data/gists-#{timestamp}.json"

        if @file.nil? || (archive != @file.to_path)
          if !@file.nil?
            @log.info "Rotating archive. Current: #{@file.to_path}, New: #{archive}"
            @file.close
          end

          @file = File.new(archive, "a+")
        end
    
        @file.puts(Yajl::Encoder.encode(gist))
      end

      remaining = response.headers['X-RateLimit-Remaining']
      reset = Time.at(response.headers['X-RateLimit-Reset'].to_i)
      @last_seen = latest.last['created_at']
      @log.info "Found #{new_gists.size} new gists: #{new_gists.collect(&@latest_key)}, API: #{remaining}, reset: #{reset}, last_seen: #{@last_seen}"

    rescue Exception => e
      @log.error "Processing exception: #{e}, #{e.backtrace.first(5)}"
      @log.error "Response: #{response.code}, #{response.headers}, #{response.body}"
    end
  end
  sleep 2
end
    sleep 2
