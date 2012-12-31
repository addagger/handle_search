module HandleSearch
  module AssociationBuilder
    module Model
      module ClassMethods
        def init_background(request={}, &block)
          self.new.tap do |s|
            s.set_background(request.with_indifferent_access, &block)
          end
        end
      end
    
      module InstanceMethods
        def background(*args, &block)
          options = args.extract_options!
          target_attributes = Array.wrap(options[:attributes]).collect {|a| a.to_sym}
          {}.with_indifferent_access.tap do |hash|
            attributes(*args, :present).each do |name, attribute|
              unless name.in?(target_attributes)
                hash.merge!(name => attribute.to_s)
              end
            end
            associations(:unblocked).each do |name, association|
              if bg = association.background(:associative, &block)
                hash.merge!(name => bg) if bg.present?
              end
            end
          end
        end

        def set_background(request={}, &block)
          request.with_indifferent_access.tap do |hash|
            associations(:unblocked).each do |name, association|
              association.wrap(hash.delete(name), &block) if name.in?(hash)
            end
            self.attributes = hash
          end
        end
  
        def show?
          @show||false
        end

        def show!
          @show = true
        end
      end
    end
  end
end