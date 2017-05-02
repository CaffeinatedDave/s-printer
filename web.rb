require 'dotenv'
require 'erb'
require 'mongo'
require 'sinatra'
require 'json'
require 'base64'

Dotenv.load

include Mongo

use Rack::Logger
use Rack::Session::Cookie, :key => 'rack.session',
  #                         :domain => ENV['DOMAIN'],
                           :path => '/',
                           :expire_after => 60 * 60, # 1 hr. 
                           :secret => 'bmJSq9SZexKAeSv8'

register do
  def auth (type)
    condition do
      if !session[:valid_user]
        redirect '/'
      end
    end
  end
end

helpers do
  def logger
    request.logger
  end
end

$db = Mongo::Client.new(ENV['MONGODB_URI'])

before do 
  if ENV['debug'] == true
    logger.info request.env.to_s
  end
end

get '/home?', :auth => :any do
  session[:login_attempted] = nil
  first = $db[:settings].find.limit(1).first
  @files = first[:images]
  @got = first[:lastCheck]
  erb :index
end

get '/' do
  erb :login
end

post '/' do
  if params[:password] == ENV['password']
    session[:valid_user] = true
    redirect '/home'
  else 
    session[:login_attempted] = true
    redirect '/'
  end
end

post '/update', :auth => :any  do
  if params['key'] != "images" 
    $db[:settings].find_one_and_update({}, 
      {"$set" => {params['key'] => params['value']}},
      {:return_document => :after}  
    )
  end
  redirect to('/home')
end

post '/imageupload', :auth => :any  do
  file = params[:file][:tempfile]
  name = params[:name]

  if file == nil or name == ""
    halt 403, "Invalid input"
  end

  grid_file = Mongo::Grid::File.new(
    file.read,
    :filename => File.basename(name)
  )

  $db.database.fs(:fs_name => 'grid').insert_one(grid_file)

  $db[:settings].find_one_and_update({},
    {"$push" => {:images => name}},
    {:return_document => :after} 
  )
  redirect to('/home')
end

get '/images/:name' do |name|
  fs = $db.database.fs(:fs_name => 'grid')
  file = fs.find_one(:filename => name)

  out = Tempfile.open("#{name}.bmp")
  fs.download_to_stream(file.id, out)
  send_file out, type: 'image/bmp', disposition: 'inline'
end

get '/deleteImage/:name', :auth => :any  do |name|
  settings = $db[:settings].find.limit(1).first
  images = settings[:images]
  images.delete(params[:name])
  $db[:settings].find_one_and_update({},
    {"$set" => {:images => images}},
    {:return_document => :after} 
  )

  fs = $db.database.fs(:fs_name => 'grid')
  file = fs.find_one(:filename => name)
  fs.delete(file.id)

  redirect to('/home')
end

get '/settings' do
  $db[:settings].find_one_and_update({}, 
    {"$set" => {:lastCheck => Time.new.to_i}},
    {:return_document => :after}
  ).to_json
end

not_found do
  status 404
  '{error: "not found"}'
end

