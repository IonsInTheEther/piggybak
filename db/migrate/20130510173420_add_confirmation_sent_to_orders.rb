class AddConfirmationSentToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :confirmation_sent, :boolean, :nil => false, :default => false
  end
end
