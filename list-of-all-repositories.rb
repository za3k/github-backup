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

sorted_files = Dir.glob("data/repos-*-*{.json.gz,.json}").sort_by do |filename|
  m = /data\/repos-(?<start>\d+)-\d+\.json(?:\.gz)?/.match filename
  m[:start].to_i unless m.nil?
end
last_filename = sorted_files.last
if last_filename
  if last_filename.end_with? ".gz"
    last_seen = nil
    puts "Skipping last file because it is an archive, #{last_filename}"
    m = /data\/repos-(?<start>\d+)-(?<end>\d+)\.json(?:\.gz)?/.match last_filename
    last_seen = m[:end].to_i unless m.nil?
    if last_seen.nil? then
      @log.error "Could not find next record after #{last_filename} (filename parse error)."
      exit(1)
    end
    @last_seen = last_seen
  else
    begin
      last_seen = nil
      puts "Resuming previous JSON file, #{last_filename}"
      Yajl::Parser.parse(File.new last_filename) do |json|
        last_seen = json['id'].to_i
      end
      @last_seen = last_seen
    rescue Exception => e
      @log.error "Processing exception: #{e}, #{e.backtrace.first(5)}"
      @log.error "Error reading file #{last_filename} as JSON. Delete this file and try again."
      exit(1)
    end
  end
end
if @last_seen > 0
  @log.info "Previous data found. Starting with repo ##{@last_seen}"
  latest = [@last_seen]
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
        archive_gzip = "data/repos-#{fbegin}-#{fend}.json.gz"

        if @file.nil? || (archive != @file.to_path)
          if !@file.nil?
            @log.info "Rotating archive. Current: #{@file.to_path}, New: #{archive}"
            [archive, archive_gzip].each do |path|
              if File.exist? path
                @log.error "Error: We want to rotate to #{archive}, but it already exists."
                exit 1
              end
            end
            if File.exist? "#{@file.to_path}.gz"
              @log.error "Error: We want to gzip #{file.to_path} -> #{file.to_path}.gz, but that exists"
              exit 1
            end
            @file.close
            @log.info "Gzipping archive #{@file.to_path}"
            `gzip #{@file.to_path}`
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
    begin
      @log.error "Response: #{response.code}, #{response.headers}, #{response.body}"
    rescue Exception => e2
      @log.error "Nesting processing exception: #{e}"
    end
    sleep 2
  end
end
