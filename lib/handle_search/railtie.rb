require 'rails'

module HandleSearch
  class Railtie < ::Rails::Railtie
    config.before_initialize do
      ActiveSupport.on_load :active_record do
        require 'handle_search/models/active_record_extension'
        ActiveRecord::Base.send(:include, HandleSearch::ActiveRecordExtension)
      end
      ActiveSupport.on_load :action_view do
        require 'handle_search/helpers/action_view_extension'
        ActionView::Base.send(:include, HandleSearch::ActionViewExtension)
      end
    end
  end
end