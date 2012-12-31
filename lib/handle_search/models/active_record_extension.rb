require 'handle_search/installer'

module HandleSearch
  
  module ActiveRecordExtension
    extend ActiveSupport::Concern
  
    module ClassMethods
      class_eval do
        include HandleSearch::Installer::Model
      end
    end
            
  end
  
end