module Piggybak
  class Payment < ActiveRecord::Base
    belongs_to :order
    belongs_to :payment_method
    belongs_to :line_item

    validates :status, presence: true
    attr_accessor :stripe_token, :reorder_customer
    attr_accessible :stripe_token, :reorder_customer

    validates_presence_of :stripe_token, :on => :create, :message => 'There was an issue processing payment. Please try again later. (001)', :if => ->(payment){payment.reorder_customer == 'new_card'}
    validates_presence_of :reorder_customer, :on => :create, :message => 'There was an issue processing payment. Please try again later. (002)', :unless => ->(payment){payment.stripe_token.present?}

    def status_enum
      ["paid"]
    end

    def month_enum
      1.upto(12).to_a
    end

    def year_enum
      Time.now.year.upto(Time.now.year + 10).to_a
    end

    def process(order)
      logger = Logger.new("#{Rails.root}/#{Piggybak.config.logging_file}")
      return true if !self.new_record?
      lolo_customer = nil
      stripe_customer = nil

      calculator = ::PiggybakStripe::PaymentCalculator::Stripe.new(self.payment_method)
      Stripe.api_key = calculator.secret_key
      begin

        plan = nil
        credit = 0

        order.line_items.sellables.each do |line_item|
          if line_item.sellable.sku.include?('connect')
            plan = Plan.find_by_sellable_id(line_item.sellable.id)
            credit = line_item.sellable.price
          end
        end

        # Create a Customer
        if self.stripe_token.present?
          stripe_customer = Stripe::Customer.create(
              :card => self.stripe_token,
              :description => "#{order.billing_address.firstname} #{order.billing_address.lastname} (#{order.email})",
              :plan => plan.present? ? plan.name : nil,
              :email => order.email,
              :account_balance => -(credit * 100).to_i
          )
        end

        # fail if customer does not belong to user
        if self.reorder_customer == 'new_card'
          lolo_customer = Customer.create(
              :user_id => order.user_id,
              :stripe_id => stripe_customer.id,
              :last_4 => stripe_customer.active_card[:last4],
              :card_type => stripe_customer.active_card[:type],
              :exp_month => stripe_customer.active_card[:exp_month],
              :exp_year => stripe_customer.active_card[:exp_year]
          )
        else
          lolo_customer = Customer.find(self.reorder_customer)
          raise 999 if lolo_customer.user_id != order.user_id
        end

        charge = Stripe::Charge.create({
                                           :amount => (order.total_due * 100).to_i,
                                           :currency => "usd",
                                           # :card => self.stripe_token,
                                           # A customer can be charged instead of a card:
                                           :customer => lolo_customer.stripe_id,
                                           :description => "Charge for #{order.email}"
                                       })

        if plan.present?
          Subscription.create(:customer_id => lolo_customer.id,
                              :plan_id => plan.id,
                              :expires_at => plan.duration_in_months.months.from_now,
                              :status => 'active')
          unless order.user.has_role?(:connect_plus_user)
            order.user.roles << Role.find_by_name('ConnectPlusUser')
          end
        end

        self.update(transaction_id: charge.id, masked_number: charge.card.last4)

        return true
      rescue Stripe::CardError => e
        self.errors.add :payment_method_id, e.message
        logger.error 'Stripe CardError: ' + e.message
        return false
      rescue => e
        logger.error e.message
        self.errors.add :payment_method_id, "An error has occurred. Please contact support@lolofit.com to continue with your order."
        return false
      end
    end

    # Note: It is not added now, because for methods that do not store
    # user profiles, a credit card number must be passed
    # If encrypted credit cards are stored on the system,
    # this can be updated
    def refund
      # TODO: Create ActiveMerchant refund integration 
      return
    end

    def details
      if !self.new_record? 
        return "Payment ##{self.id} (#{self.created_at.strftime("%m-%d-%Y")}): " #+ 
          #"$#{"%.2f" % self.total}" reference line item total here instead
      else
        return ""
      end
    end

  end
end
