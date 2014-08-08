class Piggybak::Sellable < ActiveRecord::Base
  belongs_to :item, :polymorphic => true, :inverse_of => :piggybak_sellable

  validates :sku, presence: true, uniqueness: true
  validates :description, presence: true
  validates :price, presence: true
  validates :item_type, presence: true
  validates_numericality_of :quantity, :only_integer => true, :greater_than_or_equal_to => 0

  has_many :line_items, :as => :reference, :inverse_of => :reference
  has_many :digital_attachments

  def admin_label
    self.description
  end

  def update_inventory(purchased)
    self.update_attribute(:quantity, self.quantity + purchased)
  end
  
  def is_digital?
    if self.item_type == 'PiggybakVariants::Variant'
      self.item.item.digital?
    else
      self.item.digital?
    end
  end
  
  def is_dropship_product?
    if self.item_type == 'PiggybakVariants::Variant'
      self.item.item.dropship?
    else
      self.item.dropship?
    end
  end
  
end
