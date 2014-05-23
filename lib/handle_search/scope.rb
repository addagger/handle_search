module HandleSearch
  
  class Scope
  
    MULTI_VALUE_METHODS  = [:includes, :eager_load, :preload, :select, :group,
                            :order, :joins, :where, :having, :bind, :references,
                            :extending]

    SINGLE_VALUE_METHODS = [:limit, :offset, :lock, :readonly, :from, :reordering,
                            :reverse_order, :uniq, :create_with]
  
    attr_reader :owner
    delegate :klass, :default_scope, :to => :owner
    delegate *MULTI_VALUE_METHODS.map {|name| "#{name}_values"}, :to => :relation
    delegate *SINGLE_VALUE_METHODS.map {|name| "#{name}_value"}, :to => :relation

    def initialize(owner)
      @owner = owner
    end
    
    def relation
      @relation ||=
      if default_scope
        klass.class_eval(&default_scope)
      elsif Rails.version <= "3.2.8"
        rel = ActiveRecord::Relation.new(klass, klass.arel_table)
        if klass.finder_needs_type_condition?
          rel.where(klass.send(:type_condition)).create_with(klass.inheritance_column.to_sym => klass.sti_name)
        else
          rel
        end
      else
        klass.send(:relation)
      end
    end

    def collapse_wheres
      collection = []
      equalities = where_values.grep(Arel::Nodes::Equality)

      collection << Arel::Nodes::And.new(equalities) unless equalities.empty?

      (where_values - equalities).each do |where|
        where = Arel.sql(where) if String === where
        collection << Arel::Nodes::Grouping.new(where)
      end
      Arel::Nodes::And.new(collection) if collection.any?
    end

    def includes(*args)
      args.reject! {|a| a.blank? }
      relation.includes_values = (relation.includes_values + args).flatten.uniq
    end

    def eager_load(*args)
      relation.eager_load_values += args
    end

    def preload(*args)
      relation.preload_values += args
    end

    def select(args = nil)
      if Rails.version <= "3.2.8"
        value = args||Proc.new
        if block_given?
          relation.to_a.select {|*block_args| value.call(*block_args) }
        else
          relation.select_values += Array.wrap(value)
        end       
      else
        fields = *args
        relation.select_values += fields.flatten
      end
    end

    def group(*args)
      if Rails.version <= "3.2.8"
        relation.group_values += args.flatten
      else
        relation.group_values += args
      end
    end

    def order(*args)
      if Rails.version <= "3.2.8"
        relation.order_values += args.flatten
      else
        args.flatten!
        relation.send(:validate_order_args, args)
        refers = args.reject { |arg| Arel::Node === arg }
        refers.map! { |arg| arg =~ /^([a-zA-Z]\w*)\.(\w+)/ && $1 }.compact!
        references(refers) if refers.any?
        relation.order_values = args + order_values
      end
    end

    def reorder(*args)
      if Rails.version <= "3.2.8"
        relation.reordering_value = true
        relation.order_values = args.flatten
      else
        args.flatten!
        relation.send(:validate_order_args, args)
        relation.reordering_value = true
        relation.order_values = args
      end
    end

    def joins(*args)
      args.flatten!
      relation.joins_values += args
    end

    def bind(value)
      relation.bind_values += [value]
    end

    def where(opts, *rest)
      if Rails.version <= "3.2.8"
        relation.where_values += relation.send(:build_where, opts, rest)
      else
        references(ActiveRecord::PredicateBuilder.references(opts)) if Hash === opts
        relation.where_values += relation.send(:build_where, opts, rest)
      end
    end

    def having(opts, *rest)
      if Rails.version <= "3.2.8"
        relation.having_values += relation.send(:build_where, opts, rest)
      else
        references(ActiveRecord::PredicateBuilder.references(opts)) if Hash === opts
        relation.having_values += relation.send(:build_where, opts, rest)
      end
    end
    
    def limit(value)
      relation.limit_value = value
    end

    def offset(value)
      relation.offset_value = value
    end
    
    def lock(locks = true)
      case locks
      when String, TrueClass, NilClass
        relation.lock_value = locks || true
      else
        relation.lock_value = false
      end
    end

    def from(value, subquery_name = nil)
      if Rails.version <= "3.2.8"
        relation.from_value = value
      else
        relation.from_value = [value, subquery_name]
      end
    end
    
    def uniq(value = true)
      relation.uniq_value = value
    end
    
    def create_with(value)
      relation.create_with_value = value ? create_with_value.merge(value) : {}
    end
    
    def extending(*modules, &block)
      modules << Module.new(&Proc.new) if block_given?
      if Rails.version <= "3.2.8"
        relation.send(:apply_modules, modules.flatten)
      else
        relation.extending_values += modules.flatten
        extend(*extending_values) if extending_values.any?
      end
    end
    
    def reverse_order
      relation.reverse_order_value = !reverse_order_value
    end
    
    def readonly(value = true)
      relation.readonly_value = value
    end
    
    def references!(*args)
      if Rails.version > "3.2.8"
        relation.references_values = (references_values + args.map!(&:to_s)).uniq
      end
    end
    
    def load
      if Rails.version >= "4.0.0" && (includes_values.any? || joins_values.any?)
        relation.references(*(includes_values|joins_values))
      else
        relation
      end
    end
    
  end
  
end