module HandleSearch
  module Tools
    require 'handle_search/tools/conditions'
    require 'handle_search/tools/includes'
    require 'handle_search/tools/utilities'
    
    include HandleSearch::CollapseConditions
    extend HandleSearch::ConditionsHelpers
    include HandleSearch::CollapseIncludes
    extend HandleSearch::IncludesHelpers
    extend HandleSearch::Utilities
      
  end
end