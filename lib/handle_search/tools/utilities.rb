module HandleSearch
  module Utilities
    def convert_dates!(params = {})
      datetimes = {}
      pattern = {"(1i)"=>Time.current.year, "(2i)"=>Time.current.month, "(3i)"=>Time.current.day, "(4i)"=>Time.current.hour, "(5i)"=>Time.current.min}
      keys, default_values = pattern.keys, pattern.values
      keys.reverse_each do |datekey|
        index = keys.index(datekey)
        params.each do |attribute, value|
          datekey_detected = attribute.to_s.scan(datekey)
          if !datekey_detected.empty?
            if !value.empty?
              datetimes[attribute.delete(datekey_detected.first)] ||= default_values[0..index]
              datetimes[attribute.delete(datekey_detected.first)][index] = value.to_i
            end
            params.delete(attribute)
          end
        end
      end
      datetimes.each do |attribute, datetime|
        params[attribute] = case datetime.size
        when 0..3 then
          Date.new(*datetime)
        when 4..5 then
          Time.new(*datetime)
        end
      end
      params
    end
  end
  
end