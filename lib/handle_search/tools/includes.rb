module HandleSearch
  module CollapseIncludes
     class Includes < Hash
 
      attr_reader :options, :collection

      def initialize(*args)
        @options = args.extract_options!
        @collection = []
      end

      def add(*includes)
        includes.each do |i|
          collection << i unless i.empty?
        end
        prepare!
      end

      def prepare!
        replace prepare
      end

      def prepare
        generalize_multiple_includes(collection)
      end
 
      private

      def generalize_multiple_includes(hashes = [])
        a = lambda do |r, hash|
          hash.each do |key, value|
            r[key] = value if r[key].nil?
            a.call(r[key], value)
          end
        end
        {}.tap do |result|
          hashes.each do |hash|
            a.call(result, hash) if hash.kind_of?(Hash)
          end
        end
      end
    end
   end
  module IncludesHelpers
  end
end