module ActiveMerchant #:nodoc:
  module Shipping #:nodoc:
    class Contact
      
      attr_reader :options,
                  :person_name,
                  :phone_number,
                  :company_name
      
      def initialize(options = {})
        @person_name = options[:person_name]
        @phone_number = options[:phone_number]
        @company_name = options[:company_name] 
      end
      
      def self.from(object, options={})
        return object if object.is_a? ActiveMerchant::Shipping::Contact
        attr_mappings = {
          :person_name => [:person_name],
          :phone_number => [:phone_number],
          :company_name => [:company_name]
        }
        attributes = {}
        hash_access = begin
          object[:some_symbol]
          true
        rescue
          false
        end
        attr_mappings.each do |pair|
          pair[1].each do |sym|
            if value = (object[sym] if hash_access) || (object.send(sym) if object.respond_to?(sym) && (!hash_access || !Hash.public_instance_methods.include?(sym.to_s)))
              attributes[pair[0]] = value
              break
            end
          end
        end
        self.new(attributes.update(options))
      end
      
 
      def to_hash
        {
          :person_name => person_name,
          :phone_number => phone_number,
          :company_name => company_name
        }
      end

      def to_xml(options={})
        options[:root] ||= "contact"
        to_hash.to_xml(options)
      end

      def to_s
        prettyprint.gsub(/\n/, ' ')
      end
      
      def prettyprint
        chunks = []
        chunks << @person_name
        chunks << @phone_number
        chunks << @company_name
        chunks.reject {|e| e.blank?}.join("\n")
      end
      
      def inspect
        string = prettyprint
        string << "\nName: #{@person_name}" unless @person_name.blank?
        string << "\nName: #{@company_name}" unless @company_name.blank?
        string << "\nPhone: #{@phone_number}" unless @phone_number.blank?
        string
      end
    end
      
  end
end
