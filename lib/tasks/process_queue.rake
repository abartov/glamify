require 'mediawiki_api'

CRED = 'config/wiki_credentials.yml'
TOOL_PAGE = 'User:Ijon/GLAMify'
REQS_SECTION = '===Current requests==='

namespace :queue do
  desc "go over requests on Meta and process them one after another"
  task :process => :environment do
    # read credentials
    f = File.open(CRED, 'rb')
    if f.nil?
      puts "#{CRED} not found!  Terminating."
      exit
    end
    cred_hash = YAML::load(f.read) # read DB hash
    f.close
    # setup
    puts "logging in."
    mw = MediawikiApi::Client.new('https://meta.wikimedia.org/w/api.php')
    mw.log_in(cred_hash['user'], cred_hash['password'])

    # input
    puts "reading requests."
    debugger
    reqs = slurp_requests(mw)
    puts "Found the following requests:"
    reqs.each {|r|
      puts "src: #{r[:src]}, target: #{r[:target]}, cat: #{r[:cat]}, username: #{r[:username]}"
    }

    # crunch!
    puts "crunch time!"

    # output
    spew_output(mw, reqs)
    # yalla bye
    puts "all done! :)"
  end
end

private

def slurp_requests(mw)
  reqs = []
  attempts = 0
  success = false
  until success do
    begin
      attempts += 1
      raw_toolpage = mw.get_wikitext(TOOL_PAGE).body
      from = raw_toolpage.index(REQS_SECTION)+REQS_SECTION.length+1
      to = from+raw_toolpage[from..-1].index("\n==")
      # having grabbed the current page, quickly blank out the reqs section
      new_toolpage = raw_toolpage[0..from-1] + "# ..." + raw_toolpage[to..-1]
      puts "DBG: toolpage\n#{new_toolpage}"
      # DBG # mw.edit({title: TOOL_PAGE, text: new_toolpage, summary: 'GLAMify enqueueing requests'}) # an edit conflict would fail the request # TODO: verify!
      reqs_section = raw_toolpage[from..to] # cut off the current requests section
    rescue
      # give up
      if attempts > 3
        puts "Failed thrice to grab and update the reqs.  Must be busy.  Giving up this time.  Will get 'em next time! :)"
        exit
      end
      next
    end
    success = true
  end
  debugger
  req_lines = reqs_section.split("\n")
  req_lines.each {|r|
    r.strip!
    next if (r.empty?) or (r.index(';') == nil) or (r == '# ...') # skip sample line
    req = r.split(';')
    req[0] = req[0][2..-1] if req[0][0..1] == '# '
    unless (req.length > 2) and (req[0].strip.length == 2) and (req[1].strip.length == 2) # assumes 2-letter ISO codes.  More exotic languages would have to first be configured in the db_hash anyway...
      puts "WARN: Invalid request \"#{r}\". Ignoring."
      reqs << {error: "Invalid request", req_line: r} # would be reported later
      next
    end
    username = (req[3].nil? or req[3].empty? ? nil : req[3].strip)
    reqs << {src: req[0].strip, target: req[1].strip, cat: req[2].strip, username: username}
  }
  return reqs
end
def spew_output(mw, reqs)
end

