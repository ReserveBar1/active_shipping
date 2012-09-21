module ActiveMerchant #:nodoc:
  module Shipping
    
    class ShipResponse < Response
      
      attr_reader :tracking_number # string
      attr_reader :shipper, :recipient
      attr_reader :label
      attr_reader :carrier_code, :currency, :total_price
      attr_reader :binary_barcode, :string_barcode
      attr_reader :hash_without_image
      
      def initialize(success, message, params = {}, options = {})
        @tracking_number = options[:tracking_number]
        @label = options[:label]
        @carrier_code = options[:carrier_code]
        @currency = options[:currency]
        @total_price = options[:total_price]
        @shipper, @recipient = options[:shipper], options[:recipient]
        @binary_barcode = options[:binary_barcode]
        @string_barcode = options[:string_barcode]
        # assign the entire hash and then set the image part to nil, sice we store that in a file already, do not want to store it in the database too.
        @hash_without_image = params
        begin
          @hash_without_image["ProcessShipmentReply"]["CompletedShipmentDetail"]["CompletedPackageDetails"]["Label"]["Parts"]["Image"]=nil
        rescue
          # TODO: propoer error handling
          raise @hash_without_image.inspect
        end
        super
      end
          
    end
    
  end
end