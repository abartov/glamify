require 'mediawiki_api'
require 'date'
require './lib/glamify_lib'

CRED = 'config/wiki_credentials.yml'
TOOL_PAGE = 'User:Ijon/GLAMify'
REQS_PAGE = 'User:Ijon/GLAMify/Requests'
RESULTS_PAGE = 'User:Ijon/GLAMify/Results'
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
    reqs = slurp_requests(mw)
    puts "Found the following requests:"
    reqs.each {|r|
      puts "src: #{r[:src]}, target: #{r[:target]}, cat: #{r[:cat]}, username: #{r[:username]}"
    }

    # crunch!
    puts "crunch time!"
    results = do_glamify(reqs)
    # output
    spew_output(mw, results)
    # yalla bye
    puts "all done! :)"
  end
end

private
def do_glamify(reqs)
  sugs = []
  i = 0
  tot = reqs.length
  reqs.each {|r|
    i += 1
    puts "GLAMifying request #{i} of #{tot}..."
    suggestions = GlamifyLib.glamify(r[:src], r[:target], r[:cat])
    sugs << {request: r, suggestions: suggestions}
  }
  return sugs
end
def slurp_requests(mw)
  reqs = []
  attempts = 0
  success = false
  until success do
    begin
      attempts += 1
      reqs_wikitext = mw.get_wikitext(REQS_PAGE).body
      # having grabbed the current page, quickly blank out the reqs section
      mw.edit({title: REQS_PAGE, text: '# ...', summary: 'GLAMify processing requests', bot: 'true'}) # an edit conflict would fail the request # TODO: verify!
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
  req_lines = reqs_wikitext.split("\n")
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
    username = nil
    username = req[3].strip unless req[3].nil? or req[3].empty?
    reqs << {src: req[0].strip, target: req[1].strip, cat: req[2].strip, username: username}
  }
  if reqs.length > 7 # why 7? shall we say, the seven liberal arts?
    remainder = ''
    reqs[7..-1].each {|r| remainder += "# #{r[:src]}; #{r[:target]}; #{r[:cat]}; #{r[:username]}\n" }
    mw.edit({title: REQS_PAGE, text: remainder+"# ...\n", summary: 'GLAMify requeuing overflow requests for next run', bot: 'true'}) # an edit conflict would fail the request # TODO: verify!
    reqs = reqs[0..6]
  end
  return reqs
end
def spew_output(mw, results)
  new_results = ''
  results.each {|r|
    req = r[:request]
    sug_page = "Below are #{r[:suggestions].length} suggested images from the Commons category '''[[commons:Category:#{req[:cat]}|#{req[:cat]}]]''', some of which may be appropriate to add to the indicated articles on the '#{req[:target]}' Wikipedia, based on the fact they are used in the equivalent articles on the '#{req[:src]}' Wikipedia.\n\nThey were created by the [[User:Ijon/GLAMify|GLAMify]] tool.\n\n==Suggestions==\n"
    r[:suggestions].each {|sug|
      srcpage, article, media = sug[:srcpage], sug[:article], sug[:media]
      sug_page += "# [[commons:File:#{media}|#{media}]] ==> [[:w:#{req[:target]}:#{article}|#{article}]] -- already used in [[:w:#{req[:src]}:#{srcpage}|#{srcpage}]]\n"
    }
    pagename = TOOL_PAGE+"/"+Date.today.year.to_s+"/"+Date.today.month.to_s+"/"+req[:cat]+"_#{req[:src]}_#{req[:target]}"
    puts "Posting results subpage at #{pagename}"
    mw.edit({title: pagename, text: sug_page, summary: "GLAMify results for cat '#{req[:cat]}'", bot: 'true'}) # an edit conflict would fail the request # TODO: verify!
    new_results += "# [[#{pagename}|#{req[:cat]} -- #{req[:src]} ==> #{req[:target]}]]"
    # notify user
    unless req[:username].nil?
      new_results += " (for [[User:#{req[:username]}|#{req[:username]}]])"
      puts "Notifying user #{req[:username]}"
      mw.edit({title: "User talk:#{req[:username]}", text: "Hullo!\n\n[[User:Ijon/GLAMify|GLAMify]] has just completed a report you asked for, with suggestions for integrating media from [[commons:Category:#{req[:cat]}]].\n\nThe report is [[#{pagename}|waiting for you here]]. :)  Please note that the report pages may get '''deleted''' after 60 days, so if you'd like to keep these results around, copy them somewhere else.\n\nYour faithful servant,\n\n~~~~", summary: "GLAMify has completed a report for you! :)", section: "new", bot: 'true'})
    end
    new_results += "\n"
  }
  # now append all the new pages onto the results section, if there are any
  if results.length > 0
    existing_results = mw.get_wikitext(RESULTS_PAGE).body
    puts "posting results to #{RESULTS_PAGE}"
    mw.edit({title: RESULTS_PAGE, text: existing_results + "\n#{Date.today.to_s}\n"+new_results, summary: "GLAMify appending new results", bot: 'true'})
  else
    puts "no results."
  end

end

