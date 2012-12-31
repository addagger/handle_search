module HandleSearch

  def self.install(&block)
    Installer.module_eval(&block)
  end
  
  module Installer
    
    def self.handle(*args, &block)
      options = args.extract_options!
      args.each do |name|
        klass = name.to_s.classify.constantize
        accessor_name = options.delete(:accessor)||"search"
        search_class = install_search(klass, accessor_name, options, &block)
        klass.handle_search(accessor_name, options, &block)
      end
    end
    
    def self.install_search(klass, name, options = {}, &block)
      raise TypeError, "#{klass.to_s} is not ActiveRecord::Base" unless klass <= ActiveRecord::Base
      model_name = options.delete(:model)
      search_class = case model_name
      when String, Symbol then
        model_name.to_s.classify.constantize
      when Class then
        model_name
      when nil then
        Class.new(HandleSearch::Base)
      end
      raise TypeError, "#{search_class.to_s} is not HandleSearch::Base" unless search_class <= HandleSearch::Base
      search_class.tap do |c|
        c.define_name name.to_s.classify
        c.scope(klass)
        c.class_eval(&block)
      end
    end
    
    module Model
      def handle_search(accessor_name, options = {}, &block)
        search_class = HandleSearch::Installer.install_search(self, accessor_name, options, &block)
        (class << self; self; end).instance_eval do
          define_method accessor_name do
            search_class
          end
        end
      end
    end
    
  end
  
end