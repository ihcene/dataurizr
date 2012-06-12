require 'rubygems'
require 'sinatra'
require './dataurizr.rb'

get '/' do
  send_file File.join('views', 'form_urized.html')
end

post '/do' do
  urizr = Dataurizr.new(params[:uri])
  
  urizr.available_actions.each do |action|
    urizr.send(action) if (params[action] == "yes")
  end
  
  if params[:mode] == "download"
    response.headers['Content-Type'] = 'application/force-download'
    response.headers['Content-Disposition'] = 'attachment; filename="page.html"';
  end
  
  "#{urizr.to_html}"
end