require 'dotenv'
require 'erb'
require 'mongo'
require 'sinatra'
require 'json'

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
  erb :index
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

