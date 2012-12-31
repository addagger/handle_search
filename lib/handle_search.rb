# encoding: utf-8

require "handle_search/version"

module HandleSearch

  def self.load!
    load_handle_search!
    load_association_builder!
  end

  def self.load_handle_search!
    require 'handle_search/model'
    require 'handle_search/base'
    require 'handle_search/engine'
    require 'handle_search/railtie'
  end

  def self.load_association_builder!
    require 'association_builder/model'
    require 'association_builder/association'
    HandleSearch::Base.extend HandleSearch::AssociationBuilder::Model::ClassMethods
    HandleSearch::Base.send(:include, HandleSearch::AssociationBuilder::Model::InstanceMethods)
    HandleSearch::Association.send(:include, HandleSearch::AssociationBuilder::Association)
  end

end
  
HandleSearch.load!