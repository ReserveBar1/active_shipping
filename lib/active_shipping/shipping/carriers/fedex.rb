# FedEx module by Jimmy Baker
# http://github.com/jimmyebaker

module ActiveMerchant
  module Shipping
    
    # :key is your developer API key
    # :password is your API password
    # :account is your FedEx account number
    # :login is your meter number
    class FedEx < Carrier
      self.retry_safe = true
      
      cattr_reader :name
      @@name = "FedEx"
      
      TEST_URL = 'https://gatewaybeta.fedex.com:443/xml'
      LIVE_URL = 'https://gateway.fedex.com:443/xml'
      
      CarrierCodes = {
        "fedex_ground" => "FDXG",
        "fedex_express" => "FDXE"
      }
      
      ServiceTypes = {
        "PRIORITY_OVERNIGHT" => "FedEx Priority Overnight",
        "PRIORITY_OVERNIGHT_SATURDAY_DELIVERY" => "FedEx Priority Overnight Saturday Delivery",
        "FEDEX_2_DAY" => "FedEx 2 Day",
        "FEDEX_2_DAY_SATURDAY_DELIVERY" => "FedEx 2 Day Saturday Delivery",
        "STANDARD_OVERNIGHT" => "FedEx Standard Overnight",
        "FIRST_OVERNIGHT" => "FedEx First Overnight",
        "FIRST_OVERNIGHT_SATURDAY_DELIVERY" => "FedEx First Overnight Saturday Delivery",
        "FEDEX_EXPRESS_SAVER" => "FedEx Express Saver",
        "FEDEX_1_DAY_FREIGHT" => "FedEx 1 Day Freight",
        "FEDEX_1_DAY_FREIGHT_SATURDAY_DELIVERY" => "FedEx 1 Day Freight Saturday Delivery",
        "FEDEX_2_DAY_FREIGHT" => "FedEx 2 Day Freight",
        "FEDEX_2_DAY_FREIGHT_SATURDAY_DELIVERY" => "FedEx 2 Day Freight Saturday Delivery",
        "FEDEX_3_DAY_FREIGHT" => "FedEx 3 Day Freight",
        "FEDEX_3_DAY_FREIGHT_SATURDAY_DELIVERY" => "FedEx 3 Day Freight Saturday Delivery",
        "INTERNATIONAL_PRIORITY" => "FedEx International Priority",
        "INTERNATIONAL_PRIORITY_SATURDAY_DELIVERY" => "FedEx International Priority Saturday Delivery",
        "INTERNATIONAL_ECONOMY" => "FedEx International Economy",
        "INTERNATIONAL_FIRST" => "FedEx International First",
        "INTERNATIONAL_PRIORITY_FREIGHT" => "FedEx International Priority Freight",
        "INTERNATIONAL_ECONOMY_FREIGHT" => "FedEx International Economy Freight",
        "GROUND_HOME_DELIVERY" => "FedEx Ground Home Delivery",
        "FEDEX_GROUND" => "FedEx Ground",
        "INTERNATIONAL_GROUND" => "FedEx International Ground"
      }

      PackageTypes = {
        "fedex_envelope" => "FEDEX_ENVELOPE",
        "fedex_pak" => "FEDEX_PAK",
        "fedex_box" => "FEDEX_BOX",
        "fedex_tube" => "FEDEX_TUBE",
        "fedex_10_kg_box" => "FEDEX_10KG_BOX",
        "fedex_25_kg_box" => "FEDEX_25KG_BOX",
        "your_packaging" => "YOUR_PACKAGING"
      }

      DropoffTypes = {
        'regular_pickup' => 'REGULAR_PICKUP',
        'request_courier' => 'REQUEST_COURIER',
        'dropbox' => 'DROP_BOX',
        'business_service_center' => 'BUSINESS_SERVICE_CENTER',
        'station' => 'STATION'
      }

      PaymentTypes = {
        'sender' => 'SENDER',
        'recipient' => 'RECIPIENT',
        'third_party' => 'THIRD_PARTY',
        'collect' => 'COLLECT'
      }
      
      PackageIdentifierTypes = {
        'tracking_number' => 'TRACKING_NUMBER_OR_DOORTAG',
        'door_tag' => 'TRACKING_NUMBER_OR_DOORTAG',
        'rma' => 'RMA',
        'ground_shipment_id' => 'GROUND_SHIPMENT_ID',
        'ground_invoice_number' => 'GROUND_INVOICE_NUMBER',
        'ground_customer_reference' => 'GROUND_CUSTOMER_REFERENCE',
        'ground_po' => 'GROUND_PO',
        'express_reference' => 'EXPRESS_REFERENCE',
        'express_mps_master' => 'EXPRESS_MPS_MASTER'
      }

      def self.service_name_for_code(service_code)
        ServiceTypes[service_code] || begin
          name = service_code.downcase.split('_').collect{|word| word.capitalize }.join(' ')
          "FedEx #{name.sub(/Fedex /, '')}"
        end
      end
      
      def requirements
        [:key, :password, :account, :login]
      end
      
      def find_rates(origin, destination, packages, options = {})
        options = @options.update(options)
        packages = Array(packages)
        
        rate_request = build_rate_request(origin, destination, packages, options)
        
        response = commit(save_request(rate_request), (options[:test] || false)).gsub(/<(\/)?.*?\:(.*?)>/, '<\1\2>')
        
        parse_rate_response(origin, destination, packages, response, options)
      end
      
      def find_tracking_info(tracking_number, options={})
        options = @options.update(options)
        
        tracking_request = build_tracking_request(tracking_number, options)
        response = commit(save_request(tracking_request), (options[:test] || false)).gsub(/<(\/)?.*?\:(.*?)>/, '<\1\2>')
        parse_tracking_response(response, options)
      end
      
      # send ship request (can only send for a single package)
      # shipper and recipient are contacts
      # returns the parsed response with tracking number, label, etc.
      def ship(shipper, recipient, package, options = {})
        options = @options.update(options)
        package = package
        
        ship_request = build_ship_request(shipper, recipient, package, options)
        
        response = commit(save_request(ship_request), (options[:test] || false)).gsub(/<(\/)?.*?\:(.*?)>/, '<\1\2>')

        begin
          return parse_ship_response(shipper, recipient, package, response, options), ship_request
        rescue
          xml = REXML::Document.new(response)
          message = response_message(xml)
          raise message
        end
      end
      
      
      
      protected
      def build_rate_request(origin, destination, packages, options={})
        imperial = ['US','LR','MM'].include?(origin.country_code(:alpha2))

        xml_request = XmlNode.new('RateRequest', 'xmlns' => 'http://fedex.com/ws/rate/v6') do |root_node|
          root_node << build_request_header

          # Version
          root_node << XmlNode.new('Version') do |version_node|
            version_node << XmlNode.new('ServiceId', 'crs')
            version_node << XmlNode.new('Major', '6')
            version_node << XmlNode.new('Intermediate', '0')
            version_node << XmlNode.new('Minor', '0')
          end
          
          # Returns delivery dates
          root_node << XmlNode.new('ReturnTransitAndCommit', true)
          # Returns saturday delivery shipping options when available
          root_node << XmlNode.new('VariableOptions', 'SATURDAY_DELIVERY')
          
          root_node << XmlNode.new('RequestedShipment') do |rs|
            rs << XmlNode.new('ShipTimestamp', Time.now)
            rs << XmlNode.new('DropoffType', options[:dropoff_type] || 'REGULAR_PICKUP')
            rs << XmlNode.new('PackagingType', options[:packaging_type] || 'YOUR_PACKAGING')
            
            rs << build_location_node('Shipper', (options[:shipper] || origin))
            rs << build_location_node('Recipient', destination)
            if options[:shipper] and options[:shipper] != origin
              rs << build_location_node('Origin', origin)
            end
            
            rs << XmlNode.new('RateRequestTypes', 'ACCOUNT')
            rs << XmlNode.new('PackageCount', packages.size)
            packages.each do |pkg|
              rs << XmlNode.new('RequestedPackages') do |rps|
                rps << XmlNode.new('Weight') do |tw|
                  tw << XmlNode.new('Units', imperial ? 'LB' : 'KG')
                  tw << XmlNode.new('Value', [((imperial ? pkg.lbs : pkg.kgs).to_f*1000).round/1000.0, 0.1].max)
                end
                rps << XmlNode.new('Dimensions') do |dimensions|
                  [:length,:width,:height].each do |axis|
                    value = ((imperial ? pkg.inches(axis) : pkg.cm(axis)).to_f*1000).round/1000.0 # 3 decimals
                    dimensions << XmlNode.new(axis.to_s.capitalize, value.ceil)
                  end
                  dimensions << XmlNode.new('Units', imperial ? 'IN' : 'CM')
                end
                if options[:adult_signature] && options[:adult_signature] == true
                  rps << XmlNode.new('SpecialServicesRequested') do |sps|
                    sps << XmlNode.new('SpecialServiceTypes', 'SIGNATURE_OPTION')
                    sps << XmlNode.new('SignatureOptionDetail') do |signature_option_detail|
                      signature_option_detail << XmlNode.new('OptionType', 'ADULT')
                    end
                  end
                end
              end
            end
            
          end
        end
        xml_request.to_s
      end
      
      def build_tracking_request(tracking_number, options={})
        xml_request = XmlNode.new('TrackRequest', 'xmlns' => 'http://fedex.com/ws/track/v3') do |root_node|
          root_node << build_request_header
          
          # Version
          root_node << XmlNode.new('Version') do |version_node|
            version_node << XmlNode.new('ServiceId', 'trck')
            version_node << XmlNode.new('Major', '3')
            version_node << XmlNode.new('Intermediate', '0')
            version_node << XmlNode.new('Minor', '0')
          end
          
          root_node << XmlNode.new('PackageIdentifier') do |package_node|
            package_node << XmlNode.new('Value', tracking_number)
            package_node << XmlNode.new('Type', PackageIdentifierTypes[options['package_identifier_type'] || 'tracking_number'])
          end
          
          root_node << XmlNode.new('ShipDateRangeBegin', options['ship_date_range_begin']) if options['ship_date_range_begin']
          root_node << XmlNode.new('ShipDateRangeEnd', options['ship_date_range_end']) if options['ship_date_range_end']
          root_node << XmlNode.new('IncludeDetailedScans', 1)
        end
        xml_request.to_s
      end
      
      
      
      
      #########################################   build ship request start    #########################################
      # TODO : location = > person: contact & address
      # shipper | recipient: Location
      # options 
      #     payor_account_number :required
      #     payment_type: default = SENDER (THIRD_PARTY|RECIPIENT)
      #     dropoff_type : default = REGULAR_PICKUP
      #     service_type: default = GROUND_HOME_DELIVERY
      #     packaging_type : default =" YOUR_PACKAGING"
      #     shipper_email : required
      #     recipient_email : required
      #     image_type: PDF (default) | PNG | ZPLII (thermal printer language)
      #     label_stock_type: PAPER_8.5X11_TOP_HALF_LABEL | STOCK_4X6.75_LEADING_DOC_TAB
      #     label_printing_orientation: TOP_EDGE_OF_TEXT_FIRST
      #     alcohol : default => false, set to true if the shipment contains alcohol.
      #     invoice_number : optional, prints in the shipping label
      #     po_number : optional, prints on the shipping label
      #     saturday_delivery: default => false, set to true required for all saturday delivery requests, as this is not on the service type.
      #     ship_timestamp: needs to be forced to Thursday for 2day saturday delivery test labels, etc.
      ##################################################################################################################
      def build_ship_request(shipper, recipient, package, options={})
        imperial = ['US','LR','MM'].include?(shipper.country_code(:alpha2))

        xml_request = XmlNode.new('ProcessShipmentRequest', 'xmlns' => 'http://fedex.com/ws/ship/v10') do |root_node|
          root_node << build_request_header

          # Version
          root_node << XmlNode.new('Version') do |version_node|
            version_node << XmlNode.new('ServiceId', 'ship')
            version_node << XmlNode.new('Major', '10')
            version_node << XmlNode.new('Intermediate', '0')
            version_node << XmlNode.new('Minor', '0')
          end
          
        
          root_node << XmlNode.new('RequestedShipment') do |rs|
            if options[:ship_timestamp]
              rs << XmlNode.new('ShipTimestamp', options[:ship_timestamp])
            else
              rs << XmlNode.new('ShipTimestamp', Time.now)
            end
            rs << XmlNode.new('DropoffType', options[:dropoff_type] || 'REGULAR_PICKUP')
            rs << XmlNode.new('ServiceType', options[:service_type] || 'GROUND_HOME_DELIVERY')
            rs << XmlNode.new('PackagingType', options[:packaging_type] || 'YOUR_PACKAGING')
            
            rs << build_shipper_or_recipient_node('Shipper', shipper)
            rs << build_shipper_or_recipient_node('Recipient', recipient)
            
            rs << XmlNode.new('ShippingChargesPayment') do |scp_node|
              scp_node << XmlNode.new('PaymentType', options[:payment_type] || 'SENDER')
              scp_node << XmlNode.new('Payor') do |payor_node|
                payor_node << XmlNode.new('AccountNumber', options[:payor_account_number])
                payor_node << XmlNode.new('CountryCode', shipper.country_code)
              end
            end
            rs << XmlNode.new('SpecialServicesRequested') do |special_services_node|
              special_services_node << XmlNode.new('SpecialServiceTypes', 'SATURDAY_DELIVERY') if options[:saturday_delivery]
              special_services_node << XmlNode.new('SpecialServiceTypes', 'EMAIL_NOTIFICATION')
              special_services_node << XmlNode.new('EMailNotificationDetail') do |email_node|
                email_node << XmlNode.new('Recipients') do |recipients_node|
                  recipients_node << XmlNode.new('EMailNotificationRecipientType', 'RECIPIENT')
                  recipients_node << XmlNode.new('EMailAddress', options[:shipper_email])
                  recipients_node << XmlNode.new('NotificationEventsRequested', 'ON_SHIPMENT')
                  recipients_node << XmlNode.new('Format', 'HTML')
                  recipients_node << XmlNode.new('Localization') do |localization_node|
                    localization_node << XmlNode.new('LanguageCode', 'EN')
                  end
                   
                end
              end
            end
          
            rs << XmlNode.new('LabelSpecification') do |label_node|
              label_node << XmlNode.new('LabelFormatType', 'COMMON2D')
              label_node << XmlNode.new('ImageType', options[:image_type] || 'PDF')
              label_node << XmlNode.new('LabelStockType', options[:label_stock_type] || 'PAPER_8.5X11_TOP_HALF_LABEL')
              if options[:label_stock_type] == 'STOCK_4X6.75_LEADING_DOC_TAB'
                label_node << XmlNode.new('LabelPrintingOrientation', 'TOP_EDGE_OF_TEXT_FIRST')
              end
            end
            
            rs << XmlNode.new('RateRequestTypes', 'ACCOUNT')
            rs << XmlNode.new('PackageCount', 1)

            rs << XmlNode.new('RequestedPackageLineItems') do |rps|
              rps << XmlNode.new('SequenceNumber', 1)
              rps << XmlNode.new('Weight') do |tw|
                tw << XmlNode.new('Units', imperial ? 'LB' : 'KG')
                tw << XmlNode.new('Value', [((imperial ? package.lbs : package.kgs).to_f*1000).round/1000.0, 0.1].max)
              end
              rps << XmlNode.new('Dimensions') do |dimensions|
                [:length,:width,:height].each do |axis|
                  value = ((imperial ? package.inches(axis) : package.cm(axis)).to_f*1000).round/1000.0 # 3 decimals
                  dimensions << XmlNode.new(axis.to_s.capitalize, value.ceil)
                end
                dimensions << XmlNode.new('Units', imperial ? 'IN' : 'CM')
              end
              
              # add customer references in here
              if options[:po_number]
                rps << XmlNode.new('CustomerReferences') do |reference_node|
                  reference_node << XmlNode.new('CustomerReferenceType', 'P_O_NUMBER')
                  reference_node << XmlNode.new('Value', options[:po_number])
                end
              end
              if options[:invoice_number]
                rps << XmlNode.new('CustomerReferences') do |reference_node|
                  reference_node << XmlNode.new('CustomerReferenceType', 'INVOICE_NUMBER')
                  reference_node << XmlNode.new('Value', options[:invoice_number])
                end
              end
              if options[:alcohol] && options[:alcohol] == true
                rps << XmlNode.new('SpecialServicesRequested') do |special_services_node|
                  special_services_node << XmlNode.new('SpecialServiceTypes', 'ALCOHOL')
                end
              end
              
            end

            
          end
        end
        xml_request.to_s
      end
      #########################################   build ship request end    #########################################
      
      
      
      
      
      
      def build_request_header
        web_authentication_detail = XmlNode.new('WebAuthenticationDetail') do |wad|
          wad << XmlNode.new('UserCredential') do |uc|
            uc << XmlNode.new('Key', @options[:key])
            uc << XmlNode.new('Password', @options[:password])
          end
        end
        
        client_detail = XmlNode.new('ClientDetail') do |cd|
          cd << XmlNode.new('AccountNumber', @options[:account])
          cd << XmlNode.new('MeterNumber', @options[:login])
        end
        
        trasaction_detail = XmlNode.new('TransactionDetail') do |td|
          td << XmlNode.new('CustomerTransactionId', @options[:po_number]) 
        end
        
        [web_authentication_detail, client_detail, trasaction_detail]
      end
            
      def build_location_node(name, location)
        location_node = XmlNode.new(name) do |xml_node|
          xml_node << XmlNode.new('Address') do |address_node|
            address_node << XmlNode.new('PostalCode', location.postal_code)
            address_node << XmlNode.new("CountryCode", location.country_code(:alpha2))

            address_node << XmlNode.new("Residential", true) unless location.commercial?
          end
        end
      end
      
      # Shipment nodes for shipper and recipient
      # name is shipper|recipient
      def build_shipper_or_recipient_node(name, location)
        node = XmlNode.new(name) do |xml_node|
          xml_node << XmlNode.new('Contact') do |contact_node|
            contact_node << XmlNode.new('PersonName', location.name)
            contact_node << XmlNode.new('PhoneNumber', location.phone)
            ##contact_node << XmlNode.new('CompanyName', location.company_name) if location.company_name.present?
          end
          xml_node << XmlNode.new('Address') do |address_node|
            address_node << XmlNode.new('StreetLines', location.address1)
            if location.address2
              address_node << XmlNode.new('StreetLines', location.address2)
            end
            address_node << XmlNode.new('City', location.city)
            address_node << XmlNode.new('StateOrProvinceCode', location.state)
            address_node << XmlNode.new('PostalCode', location.postal_code)
            address_node << XmlNode.new("CountryCode", location.country_code(:alpha2))
            address_node << XmlNode.new("Residential", true) unless location.commercial?
            
          end
        end
      end
            
 
      
      def parse_rate_response(origin, destination, packages, response, options)
        rate_estimates = []
        success, message = nil
        
        xml = REXML::Document.new(response)
        root_node = xml.elements['RateReply']
        
        success = response_success?(xml)
        message = response_message(xml)
        
        root_node.elements.each('RateReplyDetails') do |rated_shipment|
          service_code = rated_shipment.get_text('ServiceType').to_s
          is_saturday_delivery = rated_shipment.get_text('AppliedOptions').to_s == 'SATURDAY_DELIVERY'
          service_type = is_saturday_delivery ? "#{service_code}_SATURDAY_DELIVERY" : service_code
          
          currency = handle_uk_currency(rated_shipment.get_text('RatedShipmentDetails/ShipmentRateDetail/TotalNetCharge/Currency').to_s)
          rate_estimates << RateEstimate.new(origin, destination, @@name,
                              self.class.service_name_for_code(service_type),
                              :service_code => service_code,
                              :total_price => rated_shipment.get_text('RatedShipmentDetails/ShipmentRateDetail/TotalNetCharge/Amount').to_s.to_f,
                              :currency => currency,
                              :packages => packages,
                              :delivery_range => [rated_shipment.get_text('DeliveryTimestamp').to_s] * 2)
	    end
		
        if rate_estimates.empty?
          success = false
          message = "No shipping rates could be found for the destination address" if message.blank?
        end

        RateResponse.new(success, message, Hash.from_xml(response), :rates => rate_estimates, :xml => response, :request => last_request, :log_xml => options[:log_xml])
      end
      
      def parse_tracking_response(response, options)
        xml = REXML::Document.new(response)
        root_node = xml.elements['TrackReply']
        
        success = response_success?(xml)
        message = response_message(xml)
        
        if success
          tracking_number, origin, destination = nil
          shipment_events = []
          
          tracking_details = root_node.elements['TrackDetails']
          tracking_number = tracking_details.get_text('TrackingNumber').to_s
          
          destination_node = tracking_details.elements['DestinationAddress']
          destination = Location.new(
                :country =>     destination_node.get_text('CountryCode').to_s,
                :province =>    destination_node.get_text('StateOrProvinceCode').to_s,
                :city =>        destination_node.get_text('City').to_s
              )
          
          tracking_details.elements.each('Events') do |event|
            address  = event.elements['Address']

            city     = address.get_text('City').to_s
            state    = address.get_text('StateOrProvinceCode').to_s
            zip_code = address.get_text('PostalCode').to_s
            country  = address.get_text('CountryCode').to_s
            next if country.blank?
            
            location = Location.new(:city => city, :state => state, :postal_code => zip_code, :country => country)
            description = event.get_text('EventDescription').to_s
            
            # for now, just assume UTC, even though it probably isn't
            time = Time.parse("#{event.get_text('Timestamp').to_s}")
            zoneless_time = Time.utc(time.year, time.month, time.mday, time.hour, time.min, time.sec)
            
            shipment_events << ShipmentEvent.new(description, zoneless_time, location)
          end
          shipment_events = shipment_events.sort_by(&:time)
        end
        
        TrackingResponse.new(success, message, Hash.from_xml(response),
          :xml => response,
          :request => last_request,
          :shipment_events => shipment_events,
          :destination => destination,
          :tracking_number => tracking_number
        )
      end
      
      def parse_ship_response(shipper, recipient, packages, response, options = {})
        success, message = nil
        
        xml = REXML::Document.new(response)
        root_node = xml.elements['ProcessShipmentReply']
        
        success = response_success?(xml)
        message = response_message(xml)
        
        if success
          tracking_number, shipper, recipient, label, carrier_code, currency, total_price, binary_barcode, string_bar_code = nil
          tracking_number = root_node.get_text('CompletedShipmentDetail/CompletedPackageDetails/TrackingIds/TrackingNumber').to_s
          currency = handle_uk_currency(root_node.get_text('CompletedShipmentDetail/ShipmentRating/ShipmentRateDetails/TotalNetCharge/Currency').to_s)
          total_price = root_node.get_text('CompletedShipmentDetail/ShipmentRating/ShipmentRateDetails/TotalNetCharge/Amount').to_s.to_f
          carrier_code = root_node.get_text('CompletedShipmentDetail/CarrierCode').to_s
          # base 64 encoded binary barcode:
          binary_barcode = Base64.decode64(root_node.get_text('CompletedShipmentDetail/CompletedPackageDetails/OperationalDetail/Barcodes/BinaryBarcodes/Value').to_s)
          string_barcode = root_node.get_text('CompletedShipmentDetail/CompletedPackageDetails/OperationalDetail/Barcodes/StringBarcodes/Value').to_s
          label = Base64.decode64(root_node.get_text('CompletedShipmentDetail/CompletedPackageDetails/Label/Parts/Image').to_s)
          ShipResponse.new(success, message, Hash.from_xml(response), :xml => response, :request => last_request, :params => {}, :binary_barcode => binary_barcode, :string_barcode => string_barcode, :total_price => total_price, :currency => currency, :carrier_code => carrier_code, :tracking_number => tracking_number, :label => label)
        else
          ShipResponse.new(success, message, Hash.from_xml(response), :xml => response, :request => last_request, :params => {})
        end
      end
            
      def response_status_node(document)
        document.elements['/*/Notifications/']
      end
      
      def response_success?(document)
        %w{SUCCESS WARNING NOTE}.include? response_status_node(document).get_text('Severity').to_s
      end
      
      def response_message(document)
        response_node = response_status_node(document)
        "#{response_status_node(document).get_text('Severity').to_s} - #{response_node.get_text('Code').to_s}: #{response_node.get_text('Message').to_s}"
      end
      
      def commit(request, test = false)
        ssl_post(test ? TEST_URL : LIVE_URL, request.gsub("\n",''))        
      end
      
      def handle_uk_currency(currency)
        currency =~ /UKL/i ? 'GBP' : currency
      end
    end
  end
end
