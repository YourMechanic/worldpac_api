# frozen_string_literal: true

require 'worldpac_api/version'
require 'nokogiri'
require 'cgi'
require 'bugsnag'
require 'rest-client'
require 'active_support/all'

# rubocop:disable Metrics/BlockLength
# rubocop:disable Metrics/LineLength
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/ModuleLength
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/PerceivedComplexity
# rubocop:disable Metrics/ParameterLists

# WorldpacApi
module WorldpacApi
  class Error < StandardError; end

  class << self
    attr_accessor :redis_config, :tomcat_domain, :max_delay, :max_tries,
                  :wpc_login_url_invoice, :wpc_url_tpl,
                  :wpc_download_url_combined, :wpc_download_url_details,
                  :wpc_login_url_returns, :wpc_password, :wpc_login,
                  :wpc_url_rma_search, :wpc_url_rma_create, :wpc_url_authorized_returns,
                  :wpc_main_orders_url, :wpc_specific_orders_url,
                  :wpc_rma_reason_not_needed, :wpc_rma_reason_core, :run_worldpac_api_locally,
                  :invoice_details_keys, :required_invoice_keys

    def config
      yield self
    end

    def download_invoice(account_nums, wpc_supplier_id, supplier_id, date, days = 0)
      invoices = []
      account_numbers = [WorldpacApi.wpc_login]
      account_numbers = account_nums if supplier_id == wpc_supplier_id
      account_numbers.each_with_index do |account_number, idx|
        execute_with_retry(raise_error: true) do |delay|
          puts "#{idx + 1}: Downloading for Account: #{account_number}"
          cookies = session_cookies(
            WorldpacApi.wpc_login_url_invoice,
            user_id: account_number,
            delay: delay
          )
          page_url = format_url_wpc_invoice(date, days)
          RestClient.get(page_url, cookies: cookies)
          resp = RestClient.get(WorldpacApi.wpc_download_url_combined, headers: { 'Referer' => page_url }, cookies: cookies)
          resp_details = RestClient.get(WorldpacApi.wpc_download_url_details, headers: { 'Referer' => page_url }, cookies: cookies)
          body = resp.body.split("\n")
          body_details = resp_details.body.split("\n")
          next unless body || body_details

          # this code is to cleanup the response into searchable array
          clean_body_details = []
          fields = body_details.shift.delete('"').split(',')
          fields = fields.map { |f| f.downcase.tr(' ', '_') }
          body_details.each do |b|
            parsed_b = b.gsub('",', ';').delete('"').split(';')
            clean_body_details << Hash[*fields.zip(parsed_b).flatten]
          end

          fields = body.shift.delete('"').split(',') + ['Unit Net Price', 'Unit Core Charge', 'Description', 'List Price']
          fields = fields.map { |f| f.downcase.tr(' ', '_') }
          unless WorldpacApi.required_invoice_keys.all? { |k| fields.include?(k) }
            next
          end

          body.each do |b|
            parsed_b = b.gsub('",', ';').delete('"').split(';') # #TODO: This is kind of retarded, need a better way to do this
            invoice_hash = Hash[*fields.zip(parsed_b).flatten]
            psearch = clean_body_details.find do |details_hash|
              details_hash['invoice'] == invoice_hash['invoice'] &&
                details_hash['part_number'] == invoice_hash['part_number']
            end
            if psearch
              WorldpacApi.invoice_details_keys.each do |key|
                invoice_hash[key] = psearch[key] if psearch[key]
              end
            end
            invoice_hash['account_number'] = account_number
            invoices << invoice_hash
          end
        end
      end
      invoices
    end

    def find_or_create_wpc_rma(order_code, account_number, invoice_num, reason_code, quantity, end_date, is_core_return)
      return unless account_number

      execute_with_retry do |delay|
        cookies = session_cookies(
          WorldpacApi.wpc_login_url_returns,
          user_id: account_number,
          delay: delay
        )
        start_date = end_date - 1.year
        partnum = nil
        if order_code
          split_oc = order_code.split(':')
          partnum = split_oc.length > 2 ? split_oc[2] : split_oc[0]
        end
        return unless invoice_num

        page_url = format_url_rma_search(reason_code, start_date, end_date, partnum)
        # query whether part is eligible for RMA
        resp = RestClient.get(page_url, cookies: cookies)
        return unless resp.code == 200

        response = JSON.parse(resp.body)
        # check for existing RMAs or create new RMA
        if !response.is_a?(Array) && response['status'] == 'ERROR'
          find_wpc_rma(partnum, invoice_num, cookies, is_core_return)
        else
          create_wpc_rma(partnum, invoice_num, cookies, response, reason_code, quantity)
        end
      end
    end

    def bulk_fetch_rmas(accounts)
      response = []
      account_numbers = [WorldpacApi.wpc_login]
      account_numbers += accounts
      account_numbers.each_with_index do |account_number, idx|
        begin
          puts "#{idx + 1}: Downloading for Account: #{account_number}"
          cookies = session_cookies(
            WorldpacApi.wpc_login_url_returns,
            user_id: account_number,
            delay: 2
          )
          resp = RestClient.get(WorldpacApi.wpc_url_authorized_returns, cookies: cookies)
          response += JSON.parse(resp.body) if resp.code == 200
        rescue StandardError => e
          puts "#{e.message}\n#{e.backtrace.join("\n")}"
          Bugsnag.notify(e.message)
        end
      end
      response
    end

    def bulk_update_arrival_info(order_tracking_id)
      execute_with_retry do |delay|
        cookies = session_cookies(WorldpacApi.wpc_main_orders_url, delay: delay)
        order_url = format(WorldpacApi.wpc_specific_orders_url, order_num: order_tracking_id)
        html = RestClient.get(order_url, cookies: cookies)
        doc = Nokogiri::HTML(html)
        doc.xpath('//span[@class="truck-leave-time"]')
      end
    end

    def update_wpc_po_tracking(order_tracking_id, country = nil)
      url = tomcat_url('/YMWorldpacApi/orders/track', orderID: order_tracking_id,
                                                      country: country)
      begin
        result = RestClient.get(url)
        result = JSON.parse(result.body)
        if result&.include?('trackCodes') && !result['trackCodes'].empty?
          tracking_codes = result['trackCodes']
        end
        if result&.include?('shippingStatus') && !result['shippingStatus'].empty?
          shipping_status = result['shippingStatus']
        end
        { tracking_codes: tracking_codes, shipping_status: shipping_status }
      rescue StandardError
        Bugsnag.notify($ERROR_INFO)
      end
    end

    def search_wpc_part_by_number(partnum, country)
      res = nil
      begin
        res = RestClient.get(tomcat_url(
                               '/YMWorldpacApi/parts/search',
                               prodCode: partnum,
                               country: country
                             ))
        return [] if res.code != 200

        res = JSON.parse(res)
      rescue StandardError
        Bugsnag.notify($ERROR_INFO)
        return []
      end
      res['quotes']
    end

    def create_wpc_order(data)
      RestClient.post(tomcat_url('/YMWorldpacApi/orders/create'), JSON.generate(data))
    end

    private

    def tomcat_url(url, params = nil)
      params ||= {}
      params[:db] = WorldpacApi.redis_config[:db] || 0
      # params[:env] = Rails.env.production? ? "prod" : "stage"
      params[:env] = 'stage'
      params = params.map { |k, v| "#{k}=#{v}" }.join('&')
      "#{WorldpacApi.tomcat_domain}#{url}?#{params}"
    end

    def execute_with_retry(raise_error: false)
      tries = 0
      delay = 0
      begin
        yield(delay)
      rescue RestClient::Unauthorized => e
        puts "#{e.message}\n#{e.backtrace.join("\n")}"
      rescue StandardError => e
        tries += 1
        # retry with exponential backoff
        if tries <= WorldpacApi.max_tries
          exp_delay     = Float(2**tries)
          random_delay  = rand(0..exp_delay)
          max_exp_delay = exp_delay + random_delay
          delay         = [max_exp_delay, WorldpacApi.max_delay].min
          if e.is_a?(RestClient::ServiceUnavailable)
            delay = WorldpacApi.max_delay
          end
          puts "#{e.message}\n#{e.backtrace.join("\n")}\nRETRYING in #{delay} seconds..."
          retry
        else
          Bugsnag.notify(e.message)
          raise Error, e.message if raise_error
        end
      end
    end

    def format_url_rma_search(reason_code, start_date, end_date, part_number)
      formatted_start_date = start_date.strftime('%Y%m%d')
      formatted_end_date = end_date.strftime('%Y%m%d')
      format(WorldpacApi.wpc_url_rma_search, reason_code: reason_code, start: formatted_start_date, end: formatted_end_date, part_number: part_number)
    end

    def session_cookies(login_url, opts = {})
      user_id = opts[:user_id] || WorldpacApi.wpc_login
      data = {
        'user': user_id,
        'password': opts[:password] || WorldpacApi.wpc_password,
        'submit': 'Login',
        'remember': 'on',
        'offset': '0'
      }
      # Slight delay to avoid throttling/timeouts
      sleep(opts[:delay]) if opts[:delay]
      resp = RestClient.post(login_url, data)
      j_session_id = resp.code >= 200 && resp.code < 300 ? resp.cookies['JSESSIONID'] : nil
      cookies = {
        'JSESSIONID' => j_session_id,
        'sdx-user-settings' => user_id,
        'sdx-save-user-id' => 'true'
      }
      cookies
    end

    def format_url_wpc_invoice(from_date, days)
      d0 = from_date.strftime('%-m/%-d/%y')
      d1 = (from_date + days.day).strftime('%-m/%-d/%y')
      start_d = CGI.escape d0
      end_d = CGI.escape d1
      format(WorldpacApi.wpc_url_tpl, start: start_d, end: end_d)
    end

    def find_wpc_rma(partnum, invoice_num, cookies, is_core_return)
      execute_with_retry do
        resp = RestClient.get(WorldpacApi.wpc_url_authorized_returns, cookies: cookies)
        return if resp.code != 200

        response = JSON.parse(resp.body)
        part = if is_core_return
                 response.find do |x|
                   x['productID'] == partnum &&
                     x['invoiceNumber'] == invoice_num &&
                     x['returnReasonCode'] == WorldpacApi.wpc_rma_reason_core
                 end
               else
                 response.find do |x|
                   x['productID'] == partnum &&
                     x['invoiceNumber'] == invoice_num
                 end
               end
        return if !part || part['rmaNumber'].blank?

        part
      end
    end

    def create_wpc_rma(partnum, invoice_num, cookies, responseq, reason_code, quantity)
      execute_with_retry do
        part = responseq.find { |x| x['productID'] == partnum && x['invoiceNumber'] == invoice_num }
        return unless part

        # create new RMA
        rma_url = format(WorldpacApi.wpc_url_rma_create, reason_code: reason_code, invoice_number: invoice_num, search_lineID: part['invoiceLineID'], qty: quantity)
        resp = RestClient.get(rma_url, cookies: cookies)
        response = JSON.parse(resp.body)
        if resp.code == 200 && response['status'] == 'OK'
          return response['authorizedReturn']['rmaNumber'].strip
        end

        return nil
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
# rubocop:enable Metrics/LineLength
# rubocop:enable Metrics/MethodLength
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/ModuleLength
# rubocop:enable Metrics/CyclomaticComplexity
# rubocop:enable Metrics/PerceivedComplexity
# rubocop:enable Metrics/ParameterLists
