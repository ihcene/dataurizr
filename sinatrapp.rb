require 'rubygems'
require 'sinatra'
require './dataurizr.rb'

get '/' do
  urizr = Dataurizr.new(params[:uri])
  urizr.do_images
  urizr.do_javascript
  urizr.do_css
  urizr.do_inline_css
  
  "#{urizr.to_html}"
end