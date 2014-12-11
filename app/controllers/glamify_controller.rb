require 'media_wiki'

class GlamifyController < ApplicationController
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
    end
  end

  protected
  def glamify(src, target, cat)
    srcmw = MediaWiki::Gateway.new("https://#{src}.wikipedia.org/w/api.php")
    targetmw = MediaWiki::Gateway.new("https://#{target}.wikipedia.org/w/api.php")
    commons = MediaWiki::Gateway.new('https://commons.wikimedia.org/w/api.php')

    all_items = grab_media_items(commons, cat) # SEE ALSO: http://commonscat.tumblr.com/ :)
    used_items = find_media_usage(all_items, src)
    target_articles = find_interwikis(used_items, target)
  end
  def grab_media_items(commons, cat)
    commons.category_members("Category:#{cat}")
  end
  def find_media_usage(items, src)
    ret = []
    items.each {|item|
      # file usage not implemented in mediawiki-gateway yet.  Off to implement it. :)
    }
    return ret
  end
  def find_interwikis(items, target)
  end
  def lookup_media_in_target
  end
  def prepare_suggestions
  end
end
