module ActiveMerchant
  module Billing
    class CardFlexGateway < Gateway
      cattr_accessor :gateway_url

      self.display_name         = 'CardFlex Inc'
      self.gateway_url          = 'https://post.cfinc.com/cgi-bin/process.cgi'
      self.homepage_url         = 'http://www.cardflexnow.com/'
      self.default_currency     = 'USD'
      self.money_format         = :dollars
      self.supported_cardtypes  = [:visa, :master, :american_express, :discover]
      self.supported_countries  = ['US']

      # Creates a new CardFlexGateway
      #
      # The gateway requires that a valid login and password be passed
      # in the +options+ hash.
      #
      # ==== Options
      #
      # * <tt>:login</tt> -- The CardFlex Account ID (REQUIRED)
      # * <tt>:password</tt> -- The CardFlex Merchant PIN. (REQUIRED)
      # * <tt>:test</tt> -- +true+ or +false+. If true, perform transactions against the test server.
      #   Otherwise, perform transactions against the production server.
      def initialize(options = {})
        requires!(options, :login)
        @options = options
        super
      end

      # Performs an authorization, which reserves the funds on the customer's credit card, but does not
      # charge the card.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be captured as a FLOAT value in dollars and cents. (REQUIRED)
      # * <tt>creditcard_or_credit_card_id</tt> -- The CreditCard details for the transaction. (REQUIRED)
      # * <tt>options</tt> -- A hash of optional parameters.
      def authorize(money, creditcard_or_credit_card_id, options = {})
        post            = {}
        post[:authonly] = 1

        add_address(post, options)
        add_invoice(post, options)
        add_payment_source(post, creditcard_or_credit_card_id, options)

        commit(post[:userprofileid] ? :profile_sale : :ns_quicksale_cc, money, post)
      end

      # Captures the funds from an authorized transaction.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be captured as a FLOAT value in dollars and cents. (REQUIRED)
      # * <tt>authorization</tt> -- The authorization returned from the previous authorize request. (REQUIRED)
      # * <tt>options</tt> -- A hash of optional parameters
      def capture(money, authorization, options = {})
        post            = {}

        # remove last 4 digits of cc number as they are not required here
        post[:postonly] = authorization[0...-4]

        commit(post[:userprofileid] ? :profile_sale : :ns_quicksale_cc, money, post)
      end

      # Credit a transaction.
      #
      # This transaction indicates to the gateway that
      # money should flow from the merchant to the customer.
      #
      # ==== Parameters
      #
      # * <tt>:money</tt> -- The amount to be credited as a FLOAT value in dollars and cents (REQUIRED)
      # * <tt>:creditcard_or_credit_card_id</tt> -- The creditcard or stored creditcard id the refund is being issued to. (REQUIRED)
      # * <tt>options</tt> -- A hash of optional parameters
      def credit(money, creditcard_or_credit_card_id, options = {})
        post = {}
        add_address(post, options)
        add_invoice(post, options)
        add_payment_source(post, creditcard_or_credit_card_id, options)

        commit(post[:userprofileid] ? :profile_credit : :ns_credit, money, post)
      end

      # Perform a purchase, which is essentially an authorization and capture in a single operation.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be purchased as a FLOAT value in dollars and cents. (REQUIRED)
      # * <tt>creditcard_or_credit_card_id</tt> -- The CreditCard details for the transaction or ID of a stored credit card. (REQUIRED)
      # * <tt>options</tt> -- A hash of optional parameters.
      def purchase(money, creditcard_or_credit_card_id, options = {})
        post = {}
        add_address(post, options)
        add_invoice(post, options)
        add_payment_source(post, creditcard_or_credit_card_id, options)

        commit(post[:userprofileid] ? :profile_sale : :ns_quicksale_cc, money, post)
      end

      # Stores CreditCard details for later use.
      #
      # ==== Parameters
      #
      # * <tt>creditcard</tt> -- The CreditCard details to store. (REQUIRED)
      # * <tt>options</tt> -- A hash of optional parameters
      def store(creditcard, options = {})
        post = {}
        post[:accttype] = 1
        add_address(post, options)
        add_creditcard(post, creditcard)

        commit(:profile_add, nil, post)
      end

      # Removes stored CreditCard details.
      #
      # ==== Parameters
      #
      # * <tt>creditcard_id</tt> -- The ID of the CreditCard details to remove. (REQUIRED)
      # * <tt>options</tt> -- A hash of optional parameters
      def unstore(creditcard_id, options = {})
        commit(:profile_delete, nil, options.merge(:userprofileid => creditcard_id.to_s[0...-4].to_i, :last4digits => creditcard_id.to_s[-4..-1].to_i))
      end

      # Void a previous transaction
      #
      # ==== Parameters
      #
      # * <tt>authorization</tt> - The authorization returned from the previous authorize request. (REQUIRED)
      # * <tt>options</tt> -- A hash of optional parameters
      def void(authorization, options = {})
        commit(:ns_void, nil, options.merge(:historykeyid => authorization[0...-4], :last4digits => authorization[-4..-1]))
      end

      private
        # adds a billing or shipping address for the charge
        def add_address(post, options)
          if address = options[:billing_address] || options[:address]
            post[:ci_billaddr1]   = address[:address1]
            post[:ci_billaddr2]   = address[:address2] if address[:address2]
            post[:ci_billcity]    = address[:city]
            post[:ci_billstate]   = address[:state]
            post[:ci_billzip]     = address[:zip]
            post[:ci_billcountry] = address[:country]
          end

          if address = options[:shipping_address]
            post[:ci_shipaddr1]   = address[:address1]
            post[:ci_shipaddr2]   = address[:address2] if address[:address2]
            post[:ci_shipcity]    = address[:city]
            post[:ci_shipstate]   = address[:state]
            post[:ci_shipzip]     = address[:zip]
            post[:ci_shipcountry] = address[:country]
          end
        end

        # add a new credit card to the transaction
        def add_creditcard(post, creditcard)
          post[:ccname]   = "#{creditcard.first_name} #{creditcard.last_name}"
          post[:ccnum]    = creditcard.number
          post[:cvv2]     = creditcard.verification_value if creditcard.verification_value?
          post[:expmon]   = creditcard.month
          post[:expyear]  = creditcard.year
        end

        # add order id to charge
        def add_invoice(post, options)
          post[:merchantordernumber] = options[:order_id] if options.has_key?(:order_id)
        end

        # determine if we are using a new credit card or stored one
        def add_payment_source(post, credit_card_or_card_id, options)
          if credit_card_or_card_id.is_a?(ActiveMerchant::Billing::CreditCard)
            add_creditcard(post, credit_card_or_card_id)
          else
            post[:userprofileid]  = credit_card_or_card_id[0...-4]
            post[:last4digits]    = credit_card_or_card_id[-4..-1]
          end
        end

        def commit(action, money, parameters)
          parameters[:amount] = money unless money.nil?
          response            = parse(ssl_post(self.gateway_url, post_data(action, parameters)))
          test_mode           = @options[:test] || @options[:login] == "TEST0"

          Response.new(response[:result] == "1", response[:message], response,
            :avs_result     => { :code => response[:avs_result] },
            :authorization  => response[:authorization],
            :cvv_result     => response[:cvv_result],
            :test           => test_mode
          )
        end

        # parse response body into its components
        def parse(body)
          response = {}

          # parse reponse body into a hash
          body.gsub!("<html><body><plaintext>", "")
          body.split("\r\n").each do |pair|
            key,val = pair.split("=")
            response[key.underscore.to_sym] = val if key && val
          end

          # split response from : delimited format
          if response[:result] == "1"
            approval_response             = response[:accepted].split(":")
            response[:message]            = "Accepted"
            response[:transaction_type]   = approval_response[0]
            response[:authorization_code] = approval_response[1]
            response[:reference_number]   = approval_response[2]
            response[:batch_number]       = approval_response[3]
            response[:transaction_id]     = approval_response[4]
            response[:avs_result]         = approval_response[5]
            response[:auth_net_message]   = approval_response[6]
            response[:cvv_result]         = approval_response[7]
            response[:partial_auth]       = approval_response[8]

            # if a stored profile was added use its id for authorization otherwise
            # use the historyid, and append the last4digits of the card number so
            # that it does not have to be passed in, making it more compliant to
            # ActiveMerchant
            if response[:accountnumber]
              response[:authorization] = "#{response[:transaction_type] == 'PROFILEADD' || response[:partial_auth] == 'DUPLICATE' ? response[:userprofileid] : response[:historyid]}#{response[:accountnumber][-4..-1]}"
            end
          else
            decline_response              = response[:reason].split(":")
            response[:transaction_result] = decline_response[0]
            response[:decline_code]       = decline_response[1]
            response[:message]            = decline_response[2]
          end

          response
        end

        # format post data for transaction
        def post_data(action, parameters = {})
          post                = {}
          post[:action]       = action
          post[:usepost]      = 1
          post[:acctid]       = @options[:test] ? 'TEST0' : @options[:login]
          post[:merchantpin]  = @options[:password] if @options[:password] && !@options[:test]

          request = post.merge(parameters).map {|key,value| "#{key}=#{CGI.escape(value.to_s)}"}.join("&")
          request
        end
    end
  end
end