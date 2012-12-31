HandleSearch::Base.define_base(Face)
HandleSearch::Base.define_attribute(:fog, HandleSearch::DateWrapper)
HandleSearch::Base.define_attribute(:gof)
HandleSearch::Base.define_association(:residences)
h = HandleSearch::Base.new