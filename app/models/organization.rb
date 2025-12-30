# frozen_string_literal: true

class Organization
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paranoia

  MAX_MEMBERSHIPS = 250

  #-----------------------------------------------------------------------------
  # Fields
  #-----------------------------------------------------------------------------

  field :_id,             type: String, pre_processed: true, default: -> { BSON::ObjectId.new.to_s }
  field :name,            type: String

  field :commission_code,         type: String
  field :add_on_commission_code,  type: String

  field :force_host_to_pay_commission, type: Boolean

  belongs_to :entity

  field :seats_subaccount_id, type: String
  field :seats_designer_key, type: String
  field :seats_secret_key, type: String
  field :seats_public_key, type: String

  field :has_rebates, type: Boolean, default: false

  belongs_to :owner, class_name: 'User', inverse_of: :organization
  has_many :memberships

  belongs_to :plan

  has_one :vat

  has_one :business_info

  has_one :fee_assignment, as: :feeable

  validates_associated :plan, on: :create, message: 'A plan is required'
  before_validation :set_default_plan!, on: :create
  def set_default_plan!
    self.plan ||= Plan.default
  end

  def features_parent
    plan.features
  end

  index deleted_at: 1, owner_id: 1
  index plan_id: 1
  index({ commission_code: 1, deleted_at: 1 }, { background: true })
  index({ add_on_commission_code: 1, deleted_at: 1 }, { background: true })
  index({ deleted_at: 1, created_at: 1 }, { background: true })
  index({ deleted_at: 1, updated_at: 1 }, { background: true })
  index({ created_at: 1 }, { background: true })
  index({ updated_at: 1 }, { background: true })
  index({ entity_id: 1 }, { background: true })
  index({ owner_id: 1 }, { background: true })

  # Finds all users who belong to the Org
  #
  # @return [Array<User>]
  def members
    memberships.map(&:user).compact
  end
  alias_method :users, :members

  def listing_ids
    owner.raw_listings.pluck(:id)
  end

  def cached_listing_ids
    @cached_listing_ids ||= listing_ids
  end

  def notification_receivers listing_id=nil
    if listing_id
      memberships.where(receives_emails: true).or({listing_ids: listing_id}, {all_listings: true}).map(&:user)
    else
      memberships.where(receives_emails: true).map(&:user)
    end.compact
  end

end
