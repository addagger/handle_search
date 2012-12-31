module HandleSearch
  
  def self.load_attribute_wrapper!(name)
    if defined?(Rails.root) && Rails.root
      require File.expand_path(Rails.root.join("lib", "handle_search", "attribute_wrappers", "#{name.to_s.underscore}.rb"))
    end
  end
  
  class AttributeWrapper
    extend ActiveModel::Callbacks
    
    attr_reader :owner, :name, :errors, :options
    attr_accessor :value

    define_model_callbacks :write, :only => [:before, :after]
    
    def initialize(owner, name, options = {})
      @options = options
      @owner = owner
      @name = name
      @errors = []
      @associative = true
      options.each do |param, value|
        send("#{param}=", value)
      end
    end

    delegate :inspect, :to_s, :blank?, :empty?, :present?, :nil?, :to => :value

    def object_name(*args)
      "#{owner.object_name(*args)}[#{name}]"
    end

    def method_missing(*args, &block)
      value.send(*args, &block)
    end

    def write(value)
      run_callbacks(:write) do
        @value = value
        store!(value)
      end
    end
    
    def store!(value)
      @processed = value
    end
    
    def processed
      @processed.present? ? @processed : nil
    end
    
    def associative?
      associative
    end
    
    private
    
    attr_accessor :associative

  end
  
  class DateWrapper < HandleSearch::AttributeWrapper
    
    after_write do
      if value.present?
        begin
          store!(Date.strptime(value, "%m/%d/%Y"))
        rescue
          errors << "value '<strong>#{value}</strong>' cannot be formatted to date."
          write(nil)
        end
      end
    end
    
  end
  
end