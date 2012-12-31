module HandleSearch
  
  class Association
    attr_reader :owner, :reflection, :name, :target, :options
    delegate :klass, :class_name, :to => :reflection

    def initialize(owner, name, assoc_name, options = {})
      @options = options
      unless owner.is_a?(HandleSearch::Base)
        raise ArgumentError, "Owner is not HandleSearch::Base"
      end
      @owner = owner
      @name = name
      @reflection = owner.klass.reflections[assoc_name.to_sym]
      raise "Reflection :#{assoc_name} doesn't defined for #{owner.klass.name} model" if @reflection.nil?
      @inverse_search_class = case options[:search_class]
      when String, Symbol then
        begin
          options[:search_class].to_s.classify.constantize
        rescue NameError
          klass.send(options[:search_class])
        end
      when Class then
        raise "Invalid search class #{options[:search_class].name}" unless options[:search_class] <= HandleSearch::Base
        options[:search_class]
      else
        begin
          klass.send(owner.group)
        rescue NoMethodError
          raise "Invalid search class for #{class_name}.#{owner.group}"
        end
      end
      @target = []
      @blocked = false
    end

    delegate :inspect, :blank?, :empty?, :present?, :nil?, :to => :target

    def includes_values
      collect { |search| search.scoping.relation.includes_values }.flatten.uniq
    end
    
    def joins_values
      collect { |search| search.scoping.relation.joins_values }.flatten.uniq
    end
    
    def collapse_wheres
      node = nil
      each.with_index do |subsearch, index|
        if (subsearch_where = subsearch.scoping.collapse_wheres).present?
          subsearch_where = Arel::Nodes::Grouping.new(subsearch.scoping.collapse_wheres) if many?
          node = index > 0 ? Arel::Nodes::Or.new(node, subsearch_where) : subsearch_where
        end
      end
      node
    end
    
    def object_name(*args)
      "#{owner.object_name(*args)}[#{name}]"
    end

    def public
      self.collect {|s| s unless s.hidden?}.compact
    end

    def hidden
      self.collect {|s| s if s.hidden?}.compact
    end

    def method_missing(*args, &block)
      target.send(*args, &block)
    end

    def replace(subsearches)
      self.clear
      self << subsearches
    end

    def ===(other)
      other === target
    end

    def to_ary
      target.dup
    end
    alias_method :to_a, :to_ary

    def <<(subsearches)
      Array.wrap(subsearches).each {|s| parse_searches(s) {|subsearch| @target << subsearch}}
      target
    end
    alias_method :push, :<<

    def insert(index, subsearch)
      parse_searches(subsearch) {|s| target.insert(index, s)}
    end

    def clear
      @target.clear
    end

    def block!
      @blocked = true
    end

    def unblock!
      @blocked = false
    end

    def blocked?
      @blocked
    end

    def unblocked?
      !blocked?
    end

    def build(*args)
      build_new(*args) do |subsearch|
        @target << subsearch
        if block_given?
          yield subsearch
        end
      end
    end

    def build_and_block!(*args, &block)
      build(*args, &block).tap { block! }
    end

    def build_new(*args)
      attributes = args.extract_options!
      export = (args.first||1).times.collect do
        parse_searches(attributes) do |subsearch|
          if block_given?
            yield subsearch
          end
          subsearch
        end
      end
      args.first ? export : export.last
    end

    private
    def parse_searches(s)
      if self.blocked?
        raise ArgumentError, "Association :#{@name} is blocked!"
      end
      subsearch = case s
      when HandleSearch::Base then s
      when Hash, "new" then @inverse_search_class.new(s)
      else raise TypeError, "Type mismatch: HandleSearch::Base object needed, #{s.class.name} passed"
      end
      subsearch.associate_to(self)
      if block_given?
        yield subsearch
      end
    end
  end
  
end