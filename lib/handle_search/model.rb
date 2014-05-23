module HandleSearch

  module Model
    require 'handle_search/attribute_wrapper'
    require 'handle_search/association'
    require 'handle_search/existed_set'
    require 'handle_search/scope'
    require 'handle_search/tools'
    
    extend ActiveSupport::Concern
    
    included do
       extend ActiveModel::Callbacks
       define_model_callbacks :initialize, :associated, :scoping, :only => [:after, :before]
      include ActiveModel::Validations
      validate do
        if scope_errors.present?
          scope_errors.each do |error|
            errors.add(error.first, error.last)
          end
        end
        associations.each do |name, association|
          association.each do |subsearch|
            unless subsearch.valid?
              if association.options[:concat_errors] == true
                subsearch.errors.messages.each do |attribute, suberrors|
                  suberrors.each do |suberror|
                    errors.add("#{name}.#{attribute}".to_sym, suberror)
                  end
                end
              end
            end
          end
        end
      end
    end

    module ClassMethods
      
      def inherited(child)
        instance_variables.each do |var|
          eval("child.instance_variable_set(:#{var}, #{var}.dup)")
        end
        if child.name.nil?
          child.class_eval do
            def self.name
              @_name ||= "Search"
            end
          end
        end
      end
      
      def define_name(name)
        @_name = name.to_s.classify
      end

      def group
        @_group ||= "search"
      end
            
      def define_group(new_group)
        @_group = new_group.to_s
      end

      def scope(klass, &block)
        if klass <= ActiveRecord::Base
          @_klass = klass
        else
          raise Exception, "ActiveRecord::Base expected, #{klass.class} passed!"
        end
        if block_given?
          default_scope(&block)
        end
      end
      
      def default_scope(&block)
        if block_given?
          if klass
            @_default_scope = Proc.new &block
          else
            raise "ActiveRecord::Base expected, block passed!"
          end
        else
          @_default_scope
        end
      end
      
      def initializible?
        klass.present?
      end
    
      def klass
        @_klass
      end
      
      def attributes_names
        @_attributes ||= []
      end

      def associations_names
        @_associations ||= []
      end
      
      def define_attribute(*args)
        options = args.extract_options!
        args.each do |attr_name|
          wrapper = options.delete(:wrapper)
          wrapper_class =
          case wrapper
          when String, Symbol then
            HandleSearch.load_attribute_wrapper!(wrapper)
            wrapper.to_s.classify.constantize
          when Class then
            wrapper
          when nil then
            HandleSearch::AttributeWrapper
          end
          raise TypeError, "#{wrapper_class.to_s} is not HandleSearch::AttributeWrapper" unless wrapper_class <= HandleSearch::AttributeWrapper
          attributes_names << attr_name.to_sym
          class_eval <<-STR, __FILE__, __LINE__ + 1
            def __temp__
              @_#{attr_name} ||= #{wrapper_class.name}.new(self, :#{attr_name}, #{options})
            end
            alias_method '#{attr_name}', :__temp__
            undef_method :__temp__
        
            def #{attr_name}=(value)
              attribute(:#{attr_name}).write(value)
            end
        
            def #{attr_name}?
              attribute(:#{attr_name}).processed
            end
          STR
        end
      end
      
      def define_association(*args)
        initializible?
        options = args.extract_options!
        args.each do |association|
          assoc_name = options.delete(:as)||association
          associations_names << assoc_name.to_sym
          class_eval <<-STR, __FILE__, __LINE__ + 1
            def __temp__
              @_#{assoc_name} ||= HandleSearch::Association.new(self, :#{assoc_name}, :#{association}, #{options})
            end
            alias_method '#{assoc_name}', :__temp__
            undef_method :__temp__
          
            def #{assoc_name}=(value)
              association(:#{assoc_name}).replace(value)
            end
          STR
        end
      end
    end
    
    delegate :initializible?, :name, :klass, :attributes_names, :associations_names, :default_scope, :group, :to => "self.class"
    
    attr_reader :uniq_id, :init_attributes, :senior_association, :escape, :scope
    
    attr_accessor :param_name
    
    def initialize(request = {})
      raise Exception, "Search is uninitializible! Define default scope first." unless self.initializible?
      run_callbacks(:initialize) do
        @uniq_id = Base64.urlsafe_encode64(Time.now.send(:_dump))
        @escape = []
        @param_name = name.parameterize
        @hidden = false
        self.attributes = request
      end
    end
    
    def inspect
      "#<#{self.class.name} < HandleSearch::Base, :scoping => #{klass.name}, :attributes => #{attributes.merge(associations)}, :hidden => #{hidden?}>"
    end
    
    def attributes(*args)
      filter = Proc.new {|object, args = []| args.present? ? eval(*args.collect {|f| "object.#{f}?"}.join(" && ")) : true}
      Hash[attributes_names.collect {|name| [name, attribute(name)] if filter.call(attribute(name), args)}.compact]
    end
    
    def attribute(name)
      send(name) if name.to_sym.in?(attributes_names)
    end
    
    def associations(*args)
      filter = Proc.new {|object, args = []| args.present? ? eval(*args.collect {|f| "object.#{f}?"}.join(" && ")) : true}
      Hash[associations_names.collect {|name| [name, association(name)] if filter.call(association(name), args)}.compact]
    end

    def association(name)
      send(name) if name.to_sym.in?(associations_names)
    end
    
    def attributes=(request)
      if request.is_a?(Hash)
        @init_attributes = request
        tools.convert_dates!(request).each do |name, value|
          if attributes_names.include?(name.to_sym) || association(name).try(:unblocked?) || name.to_sym == :existed
            send("#{name}=", value)
          else
            raise ArgumentError, "Attribute :#{name} is not defined for #{klass.name} or association blocked!"
          end
        end
      end
    end
    
    def existed
      @_existed ||= ExistedSet.new(self)
    end
    
    def existed=(value)
      existed.replace(value)
    end
  
    def associate_to(association)
      unless association.is_a?(HandleSearch::Association)
        raise TypeError, "Type mismatch: #{association.class.name} passed, HandleSearch::Association expected"
      end
      unless klass == association.klass
        raise TypeError, "Type mismatch: #{self.class.name} doesn't based on #{association.class_name}"
      end
      @escape = association.owner.escape + [association.klass.name]
      associations.values.each do |association|
        if association.class_name.in?(@escape)
          association.clear
          association.block!
        end
      end
      run_callbacks(:associated) do
        @senior_association = association
      end
    end

    def senior
      senior_association.try(:owner)
    end

    def index
      senior && !hidden? ? senior_association.public.index(self) : nil
    end

    def block_all_associations!
      associations.values.each {|association| association.block!}
    end

    def hide!
      @hidden = true
      self
    end

    def hidden?
      @hidden
    end

    def unhide!
      @hidden = false
      self
    end
    
    def changed?
      @changed
    end

    def object_name(*args)
      senior ? senior_association.try(:object_name) + "[#{index if args.include?(:with_index)}]" : to_param
    end

    def root
      seniors.last||self
    end

    def with_seniors
      [self] + self.seniors
    end

    def seniors
      s, array = self, []
      array << s while s = s.senior
      array
    end

    def persisted?
      false
    end
    
    def scoping
      @scope = Scope.new(self)
      run_callbacks(:scoping) do
        if existed.present?
          scope.where(tools.smth_in_values(existed.ids, "#{klass.table_name}.id"))
        end
        associations.values.each do |association|
          alter = {association.reflection.name => association.includes_values}
          if association.any?
            case association.options[:alter]
            when nil, :includes then scope.includes(alter)
            when :joins then scope.joins(alter)
            end
          end
          if (collapse_wheres = association.collapse_wheres).present?
            scope.where(collapse_wheres)
          end
        end
        scope
      end
    end

    def load
      scoping.load
    end
    
    def to_key
      nil
    end
    
    def to_model
      self
    end
    
    def to_param
      senior ? "" : param_name
    end
    
    def to_partial_path
      ["search", group].join("/")
    end
    
    def to_path
      to_partial_path
    end
    
    def to_fields_path
      to_partial_path + "/" + klass.name.tableize
    end
    
    private
  
    def tools
      HandleSearch::Tools
    end
  
    def scope_errors
      messages = []
      attributes.each do |attribute, wrapper|
        if wrapper.errors.any?
          messages += wrapper.errors.collect {|error| [attribute, error]}
        end
      end
      messages
    end
    
  end
  
end