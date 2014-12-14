require 'media_wiki'

class GlamifyController < ApplicationController
  @srcmw = nil
  @targetmw = nil
  @commons = nil

  def index
  end

  def login
  end

  def results
    if params[:src].blank? or params[:target].blank? or params[:cat].blank?
      flash[:error] = "Must fill in all fields!"
      redirect_to :action => :index
    else
      @results = glamify(params[:src], params[:target], params[:cat])
      @target = params[:target]
      @src = params[:src]
      @cat = params[:cat]
    end
  end

  protected
  def glamify(src, target, cat)
    mw = {:src => MediaWiki::Gateway.new("https://#{src}.wikipedia.org/w/api.php"), :target => MediaWiki::Gateway.new("https://#{target}.wikipedia.org/w/api.php"), :commons => MediaWiki::Gateway.new('https://commons.wikimedia.org/w/api.php')}

    all_items = grab_media_items(mw[:commons], cat) # SEE ALSO: http://commonscat.tumblr.com/ :)
    used_items = find_media_usage(all_items, src, mw[:commons])
    return make_suggestions(used_items, src, target, mw)
  end
  def grab_media_items(commons, cat)
    commons.category_members("Category:#{cat}")
  end
  def find_media_usage(items, src, commons)
    ret = []
    items.each {|item|
      usage = commons.globalusage(item)
      src_articles = usage["#{src}.wikipedia.org"]
      next if src_articles.nil? # that media item isn't used in the source wiki.
      src_articles.each {|page|
        ret << [page, item]
      }
    }
    return ret
  end
  def make_suggestions(itempairs, src, target, mw)
    suggestions = []
    itempairs.each {|page, media|
      target_article = mw[:src].langlinks(page)[target] # find interwiki to target if available
      next if target_article.nil?
      target_images = mw[:target].images(target_article)
      raw_names = target_images.map {|t| t[t.index(':')+1..-1]} # different wikis have different localizations for the 'File:' prefix
      raw_media = media[media.index(':')+1..-1]
      suggestions << {:article => target_article, :media => media} unless raw_names.include?(raw_media)
    }
    return suggestions
  end
end
