module Piggybak
  class State < ActiveRecord::Base
    belongs_to :country
    
    default_scope -> { order('name ASC') }
    
  end
end
