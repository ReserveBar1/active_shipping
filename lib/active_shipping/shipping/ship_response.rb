module ActiveMerchant #:nodoc:
  module Shipping
    
    class ShipResponse < Response
      
      attr_reader :tracking_number # string
      attr_reader :shipper, :recipient
      attr_reader :label
      attr_reader :carrier_code, :currency, :total_price
      attr_reader :binary_barcode, :string_barcode
      
      def initialize(success, message, params = {}, options = {})
        @tracking_number = options[:tracking_number]
        @label = options[:label]
        @carrier_code = options[:carrier_code]
        @currency = options[:currency]
        @total_price = options[:total_price]
        @shipper, @recipient = options[:shipper], options[:recipient]
        @binary_barcode = options[:binary_barcode]
        @string_barcode = options[:string_barcode]
        super
      end
          
    end
    
  end
end