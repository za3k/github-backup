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
@repo_name = lambda { |e| "#{e['full_name']}" }
@last_seen = 0

sorted_files = Dir.glob("data/repos-*-*.json").sort_by do |filename|
  m = /data\/repos-(?<start>\d+)-\d+.json/.match filename
  m[:start].to_i unless m.nil?
end
last_filename = sorted_files.last
if last_filename
  begin
    last_seen = nil
    Yajl::Parser.parse(File.new last_filename) do |json|
      last_seen = json['id'].to_i
    end
    @last_seen = last_seen
  rescue Exception => e
    @log.error "Processing exception: #{e}, #{e.backtrace.first(5)}"
    @log.error "Error reading file #{last_filename} as JSON. Delete this file and try again."
    exit 1
  end
end
if @last_seen > 0
  @log.info "Previous data found. Starting with repo ##{@last_seen}"
end

while true
  begin
    response = HTTP.headers('user-agent' => 'github-user:za3k',
        'Authorization' => 'token ' + ENV['GITHUB_TOKEN'])
              .accept(:json)
              .timeout(:connect => 5, :read => 5)
              .get("https://api.github.com/repositories?since=#{@last_seen}")

    if response.code >= 300
      @log.error "Error: #{response.code} #{response.reason}, \
                  header: #{response.headers}, \
                  response: #{response.body}"
    else
      latest = Yajl::Parser.parse(response.to_s)
      ids = latest.collect(&@latest_key)
      new_repos = latest.reject { |e| @latest.include? @latest_key.call(e) }
     
      @latest = ids
      new_repos.each do |repo|
        id = @latest_key.call(repo).to_i
        fbegin, fend = (id/10000).floor*10000, (id/10000).floor*10000 + 9999
        archive = "data/repos-#{fbegin}-#{fend}.json"

        if @file.nil? || (archive != @file.to_path)
          if !@file.nil?
            @log.info "Rotating archive. Current: #{@file.to_path}, New: #{archive}"
            @file.close
          end

          @file = File.new(archive, "a+")
        end
    
        @file.puts(Yajl::Encoder.encode(repo))
      end

      if ids.last and ids.last.to_i < @last_seen.to_i then
        ni = File.new("nonincreasing", "a+")
        puts("#{@last_seen} went to #{ids.last}")
        ni.close
        exit 2
      end

      remaining = response.headers['X-RateLimit-Remaining'].to_i
      reset = Time.at(response.headers['X-RateLimit-Reset'].to_i)
      @log.info "Found #{new_repos.size} new repos: #{new_repos.collect(&@repo_name)}, API: #{remaining}, reset: #{reset}, last_seen: #{ids.last}"
      @last_seen = ids.last if ids.last

      if remaining < 500
        sleep (reset - Time.now)
      elsif new_repos.size < 3
        sleep 2
      end
    end
  rescue Exception => e
    @log.error "Processing exception: #{e}, #{e.backtrace.first(5)}"
    @log.error "Response: #{response.code}, #{response.headers}, #{response.body}"
    sleep 2
  end
end
