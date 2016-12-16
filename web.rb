require 'dotenv'
require 'erb'
require 'mongo'
require 'sinatra'
require 'json'
require 'base64'

Dotenv.load

include Mongo

use Rack::Logger

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

get '/?' do
  first = $db[:settings].find.limit(1).first
  @files = first[:images]
  @got = first[:lastCheck]
  erb :index
end

post '/update' do
  if params['key'] != "images" 
    $db[:settings].find_one_and_update({}, 
      {"$set" => {params['key'] => params['value']}},
      {:return_document => :after}  
    )
  end
  redirect to('/')
end

post '/imageupload' do
  file = params[:file][:tempfile]
  name = params[:name]

  grid_file = Mongo::Grid::File.new(
    file.read,
    :filename => File.basename(name),
    :chunk_size => 1024
  )

  $db.database.fs(:fs_name => 'grid').insert_one(grid_file)

  $db[:settings].find_one_and_update({},
    {"$push" => {:images => name}},
    {:return_document => :after} 
  )
  redirect to('/')
end

get '/images/:name' do |name|
  fs = $db.database.fs(:fs_name => 'grid')
  file = fs.find_one(:filename => name)

  out = Tempfile.open("#{name}.bmp")
  fs.download_to_stream(file.id, out)
  send_file out, type: 'image/bmp', disposition: 'inline'
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

