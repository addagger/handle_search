module HandleSearch
  module CollapseConditions
    class Conditions < Array

      attr_reader :options, :collection

      def initialize(*args)
        @options = args.extract_options!
        @collection = []
      end
   
      def add(*conditions)
        conditions.each do |c|
          collection << c unless c.empty?
        end
        prepare!
      end

      def sql_clause
        concat!
        @clause.join(" #{options[:operator]||"AND"} ")
      end

      def group
        options[:group].is_a?(TrueClass)||(options[:group] == :auto && collection.many?)
      end

      def grouped
        prepare(true)
      end
  
      def grouped!
        prepare!(true)
      end

      def prepare!(round = group)
        replace prepare(round)
      end

      def prepare(round = group)
        if sql_clause.present? && @values
          [round ? "(#{sql_clause})" : sql_clause, @values]
        else
          []
        end
      end

      private

      def concat!
        @values = {}
        @clause = []
        collection.each do |condition|
          case condition[1]
          when Hash
            @clause << condition[0].gsub(/:\w+/) do |match|
              add_key(condition[1][eval(match)])
            end
          when nil
          else
            index = 0
            @clause << condition[0].gsub(/[?]/) do |match|
              index += 1
              add_key(condition[index])
            end
          end
        end
      end
  
      def add_key(value)
        if @values.has_value?(value)
          ":#{@values.key(value)}"
        else
          key = secure_key(@values.size)
          if @values.has_key?(key)
            add_key(value)
          else
            @values[key] = value
            ":#{key}"
          end
        end
      end
   
      def secure_key(i)
        key = "a"
        i.times { key.next! }
        key.to_sym
      end

    end
  end

   module ConditionsHelpers
    def smth_like_string(query, *columns)
      CollapseConditions::Conditions.new(:group => false, :operator => "OR").tap do |c|
        if query.present? && columns.present?
          columns.each do |column|
            Array.wrap(query).each do |value|
              c.add ["#{column} ~* ?", ".*#{value}.*"]
            end
          end
        end
      end
    end

    def smth_in_range(ranges = {}, *columns)
      CollapseConditions::Conditions.new(:group => false, :operator => "OR").tap do |c|
        if ranges.kind_of?(Hash) && columns.present?
          columns.each do |column|
            ranges.each do |from, to|
              if from.present? && to.present?
                c.add ["#{column} BETWEEN ? AND ?", from, to]
              elsif from.nil? && to.present?
                c.add ["#{column} < ?", to]
              elsif from.present? && to.nil?
                c.add ["#{column} > ?", from]
              end
            end
          end
        end
      end
    end

    def smth_equal(query, *columns)
      CollapseConditions::Conditions.new(:group => false, :operator => "OR").tap do |c|
        if query.present? && columns.present?
          columns.each do |column|
            Array.wrap(query).each do |value|
              c.add ["#{column} = ?", value]
            end
          end
        end
      end
    end

    def smth_in_values(query, *columns)
      CollapseConditions::Conditions.new(:group => false, :operator => "OR").tap do |c|
        if query.present? && columns.present?
          columns.each do |column|
            value = case query
            when Fixnum then query.to_s.split
            when String then query.split
            else query.to_a
            end
            c.add ["#{column} IN (?)", value]
          end
        end
      end
    end

    def smth_in_array(query, *columns)
      CollapseConditions::Conditions.new(:group => false, :operator => "OR").tap do |c|
        if query.present? && columns.present?
          columns.each do |column|
            Array.wrap(query).each do |value|
              c.add ["? = ANY (#{column})", value]
            end
          end
        end
      end
    end
  end

end