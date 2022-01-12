# frozen_string_literal: true

require 'worldpac_api'
require 'spec_helper'

# rubocop:disable Metrics/LineLength
# rubocop:disable Metrics/BlockLength

RSpec.describe WorldpacApi do
  let(:po_tracking_response) { { tracking_codes: nil, shipping_status: nil }.to_json }
  let(:search_wpc_part_by_number_response) do
    {
      "productCode": 'Test',
      "applicationID": '0',
      "applicationNote": '',
      "positionID": 0,
      "quantityPerCar": 1,
      "quotes": [{ 'productCode' => 'W0133-2537553',
                   'brand' => 'API',
                   'productDesc' => 'Wheel Cylinder',
                   'warehouseID' => '002',
                   'releaseCutoffHour' => 16,
                   'releaseCutoffMin' => 15,
                   'releaseCutoffDaysOffset' => 0,
                   'estDeliveryHour' => 12,
                   'estDeliveryMin' => 0,
                   'estDeliveryDaysOffset' => 1,
                   'quantityAvailable' => 10,
                   'listPrice' => 4912,
                   'unitPrice' => 2003,
                   'unitCoreValue' => 0,
                   'carrier' => '',
                   'oeNote' => '',
                   'prodNote' => '',
                   'thumbURL' => 'http://img.wpac.com/live/thumb/W01332537553API.JPG',
                   'imageURL' => 'http://img.wpac.com/live/W01332537553API.JPG',
                   'orderCode' => 'WPC:API:W0133-2537553' },
                 { 'productCode' => 'W0133-1639396',
                   'brand' => 'PBR',
                   'productDesc' => 'Wheel Cylinder',
                   'warehouseID' => '002',
                   'releaseCutoffHour' => 16,
                   'releaseCutoffMin' => 15,
                   'releaseCutoffDaysOffset' => 0,
                   'estDeliveryHour' => 12,
                   'estDeliveryMin' => 0,
                   'estDeliveryDaysOffset' => 1,
                   'quantityAvailable' => 10,
                   'listPrice' => 4962,
                   'unitPrice' => 222,
                   'unitCoreValue' => 0,
                   'carrier' => '',
                   'oeNote' => '',
                   'prodNote' => '',
                   'thumbURL' => 'http://img.wpac.com/live/thumb/W01331639396PBR.JPG',
                   'imageURL' => 'http://img.wpac.com/live/W01331639396PBR.JPG',
                   'orderCode' => 'WPC:PBR:W0133-1639396' },
                 { 'productCode' => 'W0133-2089994',
                   'brand' => 'DOR',
                   'productDesc' => 'Wheel Cylinder First Stop',
                   'warehouseID' => '022',
                   'releaseCutoffHour' => 17,
                   'releaseCutoffMin' => 15,
                   'releaseCutoffDaysOffset' => 0,
                   'estDeliveryHour' => 16,
                   'estDeliveryMin' => 0,
                   'estDeliveryDaysOffset' => 4,
                   'quantityAvailable' => 3,
                   'listPrice' => 4912,
                   'unitPrice' => 637,
                   'unitCoreValue' => 0,
                   'carrier' => '',
                   'oeNote' => '',
                   'prodNote' => '',
                   'thumbURL' => 'http://img.wpac.com/live/thumb/W01332089994DOR.JPG',
                   'imageURL' => 'http://img.wpac.com/live/W01332089994DOR.JPG',
                   'orderCode' => 'WPC:DOR:W0133-2089994' }]
    }.to_json
  end
  before :all do
    WorldpacApi.config do |c|
      c.tomcat_domain = 'http://localhost:8080'
      c.redis_config = { host: '127.0.0.1', timeout: 60, db: 1, password: nil }
      c.wpc_login = '123456'
      c.wpc_password = 'password'
      c.wpc_login_url_invoice = 'wpc_login_url_invoice'
      c.wpc_url_tpl = 'wpc_url_tpl'
      c.wpc_download_url_combined = 'wpc_download_url_combined'
      c.wpc_download_url_details = 'wpc_download_url_details'

      c.wpc_login_url_returns = 'wpc_login_url_returns'
      c.wpc_url_rma_search = 'wpc_url_rma_search'
      c.wpc_url_rma_create = 'wpc_url_rma_create'
      c.wpc_url_authorized_returns = 'wpc_url_authorized_returns'
      c.wpc_main_orders_url = 'wpc_main_orders_url'
      c.wpc_specific_orders_url = 'wpc_specific_orders_url'

      c.wpc_rma_reason_not_needed = 'noreason'
      c.wpc_rma_reason_core = 'corereason'

      c.run_worldpac_api_locally = false; # set this to true if would like to run WorldpacApi in local Tomcat.
      c.max_tries     = 3
      c.max_delay     = 32

      c.invoice_details_keys = %w[
        unit_net_price
        unit_core_charge
        description
        list_price
      ].freeze

      c.required_invoice_keys = %w[
        date
        invoice
        order_id
        invoice_date
        part_number
      ].freeze
    end
  end

  it 'has a version number' do
    expect(WorldpacApi::VERSION).not_to be nil
  end

  # download_invoice
  it 'download_invoice' do
    stub_request(:post, 'http://wpc_login_url_invoice/')
      .to_return(status: 200, body: "", headers: {})
    stub_request(:get, 'http://wpc_url_tpl/')
      .to_return(status: 200, body: "", headers: {})
    stub_request(:get, 'http://wpc_download_url_combined/')
      .to_return(status: 200, body: "\"Date\",\"Invoice\",\"Part Number\",\"MFG\",\"Description\",\"Qty Ordered\",\"Qty Shipped\",\"List Price\",\"Unit Net Price\",\"Unit Core Charge\",\"Total Net Price\",\"Order\",\"Purchase Order\"\n\"Wed, Aug 18, 2021\",\"31122170\",\"W0133-2512572\",\"ACD\",\"PCV Valve\",\"1\",\"1\",\"17.42\",\"12.02\",\"0.00\",\"12.02\",\"84313552\",\"4477237-6\"\n\"Wed, Aug 18, 2021\",\"31122170\",\"W0133-3617220\",\"ACD\",\"PCV Hose\",\"1\",\"1\",\"45.11\",\"39.87\",\"0.00\",\"39.87\",\"84313552\",\"4477237-6\"\n\"Wed, Aug 18, 2021\",\"31122170\",\"W0133-2549240\",\"ACD\",\"PCV Valve\",\"1\",\"1\",\"32.76\",\"16.89\",\"0.00\",\"16.89\",\"84313552\",\"4477237-6\"\n\"Wed, Aug 18, 2021\",\"31122580\",\"W0133-1784915\",\"ATE\",\"Brake Master Cylinder\",\"1\",\"1\",\"465.00\",\"188.83\",\"0.00\",\"188.83\",\"84342320\",\"4499229-1\"\n\n", headers: {})
    stub_request(:get, 'http://wpc_download_url_details/')
      .to_return(status: 200, body: "Date,\"PO Number\",\"Order ID\",\"Invoice\",\"Invoice Date\",\"Part Number\",\"Qty Shipped\",\"Billed Unit Price\",\"Freight\",\"Billed Ext Price\",\"Brand ID\"\n\"08/18/2021\",\"4477237-6\",\"84313552\",\"31122170\",\"08/18/2021\",\"W0133-2512572\",\"1\",\"12.02\",\"29.88\",\"12.02\",\"ACD\"\n\"08/18/2021\",\"4477237-6\",\"84313552\",\"31122170\",\"08/18/2021\",\"W0133-3617220\",\"1\",\"39.87\",\"29.88\",\"39.87\",\"ACD\"\n\"08/18/2021\",\"4477237-6\",\"84313552\",\"31122170\",\"08/18/2021\",\"W0133-2549240\",\"1\",\"16.89\",\"29.88\",\"16.89\",\"ACD\"\n\"08/18/2021\",\"4499229-1\",\"84342320\",\"31122580\",\"08/18/2021\",\"W0133-1784915\",\"1\",\"188.83\",\"27.86\",\"188.83\",\"ATE\"\n\n", headers: {})
    date = Date.parse('18/07/2021')
    resp = WorldpacApi.download_invoice(['123456'], '2', '2', date, 2)
    expect(resp).to eq([])
  end

  # test find_or_create_wpc_rma
  it 'find_or_create_wpc_rma' do
    stub_request(:post, 'http://wpc_login_url_returns/')
      .to_return(status: 200, body: "", headers: {})
    stub_request(:get, 'http://wpc_url_rma_search/')
      .to_return(status: 200, body: { "status" => "ERROR", "errorMsg" => "Return Reason is invalid" }.to_json, headers: {})
    date = Date.parse('18/07/2021')
    stub_request(:get, 'http://wpc_url_authorized_returns/')
      .to_return(status: 200, body: "", headers: {})
    resp = WorldpacApi.find_or_create_wpc_rma("5001-248981", '133840', 'invoice_num', 'noreason', 1, date, 'true')
    expect(resp).to eq(nil)
  end

  # bulk_fetch_rmas
  it 'bulk_fetch_rmas' do
    stub_request(:post, 'http://wpc_login_url_returns/')
      .to_return(status: 200, body: "", headers: {})
    stub_request(:get, "http://wpc_url_authorized_returns/")
      .to_return(status: 200, body: '', headers: {})
    response = WorldpacApi.bulk_fetch_rmas(['123456'])
    expect(response).to eq([])
  end

  # bulk_update_arrival_info
  it 'bulk_update_arrival_info' do
    stub_request(:post, 'http://wpc_login_url_returns/')
      .to_return(status: 200, body: "", headers: {})
    stub_request(:post, "http://wpc_main_orders_url/")
      .to_return(status: 200, body: "", headers: {})
    stub_request(:get, "http://wpc_specific_orders_url/")
      .to_return(status: 200, body: "", headers: {})
    order_tracking_id = 63_443_771
    expect(WorldpacApi.bulk_update_arrival_info(order_tracking_id)).to match_array([])
  end

  it 'update_wpc_po_tracking' do
    stub_request(:get, 'http://localhost:8080/YMWorldpacApi/orders/track?country=US&db=1&env=stage&orderID=4397045')
      .to_return(status: 200, body: po_tracking_response, headers: {})
    response = WorldpacApi.update_wpc_po_tracking(4_397_045, 'US')
    expect(response.to_json).to eq(po_tracking_response)
  end

  it 'search_wpc_part_by_number' do
    stub_request(:get, 'http://localhost:8080/YMWorldpacApi/parts/search?country=US&db=1&env=stage&prodCode=TEST')
      .to_return(status: 200, body: search_wpc_part_by_number_response, headers: {})
    response = WorldpacApi.search_wpc_part_by_number('TEST', 'US')
    expect(response).to eq(JSON.parse(search_wpc_part_by_number_response)['quotes'])
  end

  # create_wpc_order
  it 'create_wpc_order' do
    data = { "contact_name" => "",
             "address_line1" => "3637 Snell Avenue",
             "address_line2" => "",
             "city" => "San Jose",
             "state" => "CA",
             "zipcode" => "95136",
             "country" => "US",
             "note" => "YMShipQ",
             "book_now" => false,
             "parts" =>
     [{ "action" => nil,
        "backup_price" => nil,
        "brand_img" => nil,
        "brand_name" => "Beru",
        "case_id" => 4_397_048,
        "core_value" => 0,
        "cost" => 1673,
        "created_at" => "2022-01-19T06:17:23-08:00",
        "deliver_in" => 3,
        "description" => "Spark Plug",
        "descriptors" => "New,Aftermarket",
        "flags" => 0,
        "id" => 30_058_604,
        "img_hires" => "/proxy/img.eautopartscatalog.com/hires/W01332059461BER.JPG",
        "img_thumb" => "/proxy/img.eautopartscatalog.com/live/thumb/W01332059461BER.JPG",
        "list_price" => 3478,
        "misc_reason" => nil,
        "name" => "Spark Plug",
        "notes" => "Series: IRI\\nSeries: IRI\n12 ZR-6 MIP2L",
        "order_code" => "WPC:BER:W0133-2059461",
        "part_category_id" => 1411,
        "price" => 2676,
        "pricing_profile_name" => "Base_global_pricing_profile",
        "provider" => nil,
        "purchase_order_id" => 821_028,
        "quantity" => 4,
        "return_purchase_order_id" => nil,
        "rma_number" => nil,
        "supplier" => "Worldpac",
        "upc" => "",
        "updated_at" => "2022-01-19T06:17:23-08:00",
        "optional_part" => false,
        "return_receipt_url" => nil,
        "pickup_receipt_url" => nil }] }

    stub_request(:post, "http://localhost:8080/YMWorldpacApi/orders/create?db=1&env=stage")
      .with(body: data.to_json)
      .to_return(status: 200, body: "", headers: {})
    response = WorldpacApi.create_wpc_order(data)
    expect(response.code).to eq(200)
  end
end
# rubocop:enable Metrics/LineLength
# rubocop:enable Metrics/BlockLength
