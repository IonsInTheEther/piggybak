module CartDecorator
  extend ActiveSupport::Concern
 
  module InstanceMethods
    def is_digital?
      items = self.sellables
      items.all? { |i| i.is_digital? }
    end
  end
end
 
::Piggybak::Cart.send(:include, CartDecorator)