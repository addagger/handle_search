module HandleSearch
  module AssociationBuilder
    module Association
      def index_map
        Hash[ public.collect.with_index {|s, index| [index, target.index(s)]} ]
      end

      def remove(*args, &block)
        hash = args.extract_options!.with_indifferent_access
        real_index = index_map[hash[:index]]
        subsearch = hash[:object].is_a?(@inverse_search_class) ? hash[:object] : nil
        if subsearch.present? && real_index.present?
          export = target.delete(subsearch) if target.index(subsearch) == real_index
        elsif subsearch.present?
          export = target.delete(subsearch)
        elsif real_index.present?
          export = target.delete_at(real_index)
        else
          export = target.clear
        end
        if block_given? && args.include?(:yield)
          yield self, export
        end
      end

      def place(*args, &block)
        hash = args.extract_options!.with_indifferent_access
        real_index = index_map[hash[:index]]
        subsearch = case hash[:object]
        when Hash then @inverse_search_class.init_background(hash[:object], &block)
        when @inverse_search_class then hash[:object]
        when nil then @inverse_search_class.new
        else return nil
        end
        real_index.present? ? insert(real_index, subsearch) : self << subsearch
        if block_given? && args.include?(:yield)
          yield self, subsearch
        end
      end

      def background(*args, &block)
        {}.tap do |hash|
          if target.present?
            backgrounds = target.collect do |subsearch|
              subsearch.background(*args, &block)
            end
            hash[:bg] = backgrounds
          end
          if block_given?
            yield self, hash
          end
        end
      end

      def wrap(request={}, &block)
        request.with_indifferent_access.tap do |hash|
          Array.wrap(hash[:bg]).each do |item|
            place({:object => item}, &block)
          end
          if hash[:act].is_a?(Hash)
            hash[:act].each do |action, h|
              send("#{action}", :yield, h, &block)
            end
          end
        end
      end
    end
  end
end