require 'dhole' # from dhole gem

module GlamifyLib
  public
  def GlamifyLib.glamify(src, target, cat)
    db_hash = read_db_hash
    db_connect(db_hash, 'commons')
    all_items = grab_media_items(cat.gsub(' ','_')) # SEE ALSO: http://commonscat.tumblr.com/ :)
    used_items = find_media_usage(all_items, src)
    db_connect(db_hash, src)
    relevant_items = filter_by_langlink(used_items, src, target)
    db_connect(db_hash, target)
    return make_suggestions(relevant_items, src, target)
  end
  protected
  def GlamifyLib.read_db_hash
    f = File.open('config/db_hash.yml', 'rb')
    if f.nil?
      puts "config/db_hash.yml not found!  Terminating."
      exit
    end
    db_hash = YAML::load(f.read) # read DB hash
  end
  def GlamifyLib.db_connect(db_hash, lang_iso)
    if db_hash[lang_iso].nil?
      db = lang_iso+'wiki_p'
      k = db.keys.first # default to other params from whatever IS in the config file (a safe assumption on the Wikimedia Tool Labs cluster)a
    else
      db = db_hash[lang_iso]['db']
      k = lang_iso
    end
    user = db_hash[k]['user']
    passwd = db_hash[k]['password']
    host = db_hash[k]['host']

    print "connecting to #{db}..."
    Dhole::Dhole.new('mysql2', db, user, passwd, host)
    puts " connected!"
  end

  def GlamifyLib.grab_media_items(cat)
    puts "Grabbing media from Commons [[Category:#{cat}]]..."
    c = Dhole::Category.find_by_cat_title(cat)
    return [] if c.nil?
    puts "#{c.cat_files} files in category"
    return c.member_file_titles
  end
  def GlamifyLib.filter_by_langlink(items, src, target)
    ret = []
    i = 0
    items.each {|pid, item|
      puts "#{i} source pages processed... #{ret.length} target pages found so far by langlinks." if i % 10 == 0
      i += 1
      p = Dhole::Page.find_by_page_id(pid)
      if p.nil?
        puts "WARN: couldn't find #{src}wiki page id #{pid}. Skipping."
        next
      end
      target_article = p.langlinks.where(ll_lang: target).pluck(:ll_title).first # find interwiki to target if available
      next if target_article.nil?
      ret << [p.page_title, target_article, item] # src page name, target page name, media file name
    }
    return ret
  end
  # returns an array of page-ids and media name pairs.
  def GlamifyLib.find_media_usage(items, src)
    ret = []
    i = 0
    items.each {|item|
      puts "#{i} images processed... #{ret.length} usages found so far." if i % 10 == 0
      i += 1
      img = Dhole::Image.find_by_img_name(item)
      next if img.nil?
      usage = img.global_usage_by_project
      src_page_ids = usage["#{src}wiki"]
      next if src_page_ids.nil? # that media item isn't used in the source wiki.
      src_page_ids.each {|pid|
        ret << [pid, item]
      }
    }
    return ret
  end
  def GlamifyLib.make_suggestions(itemtuples, src, target)
    suggestions = []
    i = 0
    puts "#{itemtuples.length} images used on #{src} Wikipedia found! :)"
    itemtuples.each {|srcpage, targetpage, media|
      puts "#{i} images processed... #{suggestions.length} suggestions found so far." if i % 10 == 0
      i += 1
      p = Dhole::Page.find_by_page_title(targetpage.gsub(' ','_'))
      if p.nil?
        puts "WARN: couldn't find target page [[#{targetpage}]]!"
        next
      end
      target_images = p.imagelinks.pluck(:il_to)
      suggestions << {:srcpage => srcpage, :article => targetpage, :media => media} unless target_images.include?(media)
    }
    return suggestions
  end

end

