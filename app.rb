require 'sinatra/base'
require 'easypost'
require 'printnode'
require 'tilt/erb'
require 'dotenv'
require './lib/printlabel/helpers'

class App < Sinatra::Base
  configure do
    Dotenv.load
    
    # Correct client initialization
    client = EasyPost::Client.new(api_key: ENV['EASYPOST_TEST_API_KEY'])
    set :easypost_client, client
    
    set :printnode_client, PrintNode::Client.new(PrintNode::Auth.new(ENV["PRINTNODE_API_KEY"]))
    set :printer_id, ENV['PRINTNODE_PRINTER_ID']
  end

  helpers PrintLabel::Helpers

  get "/shipments" do
    opts = {}
    if params["before_id"]
      opts[:before_id] = params["before_id"]
    elsif params["after_id"]
      opts[:after_id] = params["after_id"]
    end

    # Use .all() method instead of .list()
    shipments = settings.easypost_client.shipment.all(opts)
    erb :shipments, locals: { shipments: shipments }
  end

  get "/shipments/:shipment_id/zpl/generate" do
    # Retrieve shipment using .retrieve() method
    shipment = settings.easypost_client.shipment.retrieve(params['shipment_id'])
    
    # Generate label if not already exists
    shipment.label(file_format: "ZPL") unless shipment.postage_label&.label_zpl_url
    
    redirect back
  end

  get "/shipments/:shipment_id/zpl/print" do
    # Retrieve shipment using .retrieve() method
    shipment = settings.easypost_client.shipment.retrieve(params['shipment_id'])
    
    printjob = PrintNode::PrintJob.new(
      settings.printer_id,
      shipment.id,
      'raw_uri',
      shipment.postage_label.label_zpl_url,
      'PrintLabel'
    )
    
    settings.printnode_client.create_printjob(printjob, {})
    
    redirect back
  end

  get "/" do
    redirect "/shipments"
  end

  # Run if this file is executed directly
  run! if app_file == $0
end
