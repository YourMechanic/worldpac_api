# WorldpacApi

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/worldpac_api`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'worldpac_api'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install worldpac_api

## Usage

After installing the gem create a file worldpac.rb in config/initializers with following content:

```ruby
WorldpacApi.config do |c|
    c.tomcat_domain = 'http://localhost:8080'
    c.redis_config = { host: '127.0.0.1', timeout: 60, db: 1, password: nil }
    c.wpc_login = '123456'
    c.wpc_password = 'password'
    c.wpc_login_url_invoice = 'http://sdbeta.worldpac.com/speeddial/orders/invoices.jsp'
    c.wpc_url_tpl = 'http://sdbeta.worldpac.com/speeddial/orders/invoices.jsp?env=2010&range=0&fromDate=%{start}&throughDate=%{end}&comment=&invoice=&type=0&order=&name=&product='
    c.wpc_download_url_combined = 'http://sdbeta.worldpac.com/speeddial/orders/download-invoicecombined.jsp?format=csv'
    c.wpc_download_url_details = 'http://sdbeta.worldpac.com/speeddial/orders/download-invoicedetails.jsp?format=csv'

    c.wpc_login_url_returns = 'http://sdbeta.worldpac.com/speeddial/pnaorder.jsp'
    c.wpc_url_rma_search = 'http://sdbeta.worldpac.com/speeddial/ax/eligibleReturns.jsp?reasonCode=%{reason_code}&fromDate=%{start}&throughDate=%{end}&product=%{part_number}&invoiceNumber=&order=&comment='
    c.wpc_url_rma_create = 'http://sdbeta.worldpac.com/speeddial/ax/createRma.jsp?index=0&invoiceNumber=%{invoice_number}&invoiceLineID=%{search_lineID}&createRMAQty=%{qty}&reasonCode=%{reason_code}&reasonText='
    c.wpc_url_authorized_returns = 'http://sdbeta.worldpac.com/speeddial/ax/authorizedReturns.jsp'
    c.wpc_main_orders_url = 'http://sdbeta.worldpac.com/speeddial/order.jsp?env=2010&order=76368991'
    c.wpc_specific_orders_url = 'http://sdbeta.worldpac.com/speeddial/order.jsp?env=2010&order=%{order_num}'

    c.wpc_rma_reason_not_needed = 'noreason'
    c.wpc_rma_reason_core = 'corereason'

    c.run_worldpac_api_locally = false; 
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
```

to Create an Order
```ruby
WorldpacApi.create_wpc_order(data)
```

to Track Order
```ruby
WorldpacApi.update_wpc_po_tracking('order_tracking_id', 'country')
```

to Parts Search
```ruby
WorldpacApi.search_wpc_part_by_number('PART_NUMBER', 'COUNTRY')
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/worldpac_api. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the WorldpacApi project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/worldpac_api/blob/master/CODE_OF_CONDUCT.md).
