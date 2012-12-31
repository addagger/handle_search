module HandleSearch
  class ExistedSet
    attr_reader :owner, :target
    delegate :klass, :to => :owner

    def initialize(owner)
      @owner = owner
      @target = []
      @blocked = false
    end

    delegate :inspect, :blank?, :empty?, :present?, :present?, :nil?, :to => :target

    def method_missing(*args, &block)
      target.send(*args, &block)
    end

    def replace(item)
      self.clear
      self << item
    end

    def ===(other)
      other === target
    end

    def to_ary
      target.dup
    end
    alias_method :to_a, :to_ary

    def <<(items)
      Array.wrap(items).each {|i| parse_items(i) {|item| @target << item}}
      target
    end
    alias_method :push, :<<

    def clear
      @target.clear
    end

    def block!
      @blocked = true
      clear
    end

    def blocked?
      @blocked
    end

    def ids
      self.collect {|i| i.id.to_s}
    end

    private
    def parse_items(item)
       if self.blocked?
        raise ArgumentError, "ExistedSet for #{owner.class.name} blocked"
      end
      record = case item
      when klass then item
      when Fixnum, String then klass.find(item)
      else raise TypeError, "Type mismatch: #{klass.name} needed, or Fixnum/String as ID, #{item.class.name} passed"
      end
      unless record.persisted?
        raise ArgumentError, "Item is not persisted!"
      end
      if block_given?
        yield record
      end
    end

  end
end