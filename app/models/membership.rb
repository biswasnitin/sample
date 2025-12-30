class Membership
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paranoia

  field :_id, type: String, pre_processed: true, default: -> { BSON::ObjectId.new.to_s }

  # Email exists in order to do an initial association of membership and a
  # user, or to invite a new user to the site. The field should not be
  # otherwised used in place of User.email
  field :email,        type: String
  field :token,        type: String, default: ->{ SecureRandom.hex(32) }
  field :activated_at, type: DateTime
  field :all_listings, type: Boolean, default: false
  field :state,        type: String

  field :role_name,    type: String

  belongs_to :user, counter_cache: true
  belongs_to :organization
  has_and_belongs_to_many :listings

  before_create         :sanitize_email
  before_create         :find_user
  after_create          :activate_or_invite

  index({deleted_at: 1, user_id: 1, organization_id: 1})
  index({deleted_at: 1, organization_id: 1})
  index({organization_id: 1, user_id: 1})
  index({token: 1})
  index({promote: 1, all_listings: 1}, {background: true})
  index({user_id: 1, listing_ids: 1, deleted_at: 1}, {background: true})
  index({user_id: 1, organization_id: 1, all_listings: 1, deleted_at: 1}, {background: true})

  scope :active, -> { where(state: 'active') }
  scope :pending, -> { where(state: 'pending') }

  validates_presence_of :organization_id

  validates_presence_of :email
  validates :email, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i,
                              message: "must be formatted like an email" }

  validate :duplicate_email, on: :create

  validate :creatable_has_all_permissions, on: [:create, :update]

  validate :owner_email, on: :create

  validate :below_limit, on: :create

  state_machine :state, initial: :pending do
    state :pending
    state :active

    # Transions state from pending to active if the membership has a user_id
    # and no existing, persisted membership with the same user/organization
    event :activate do
      transition pending: :active, if: lambda { |membership|
        membership.user_id? && Membership.active.where(user_id: membership.user_id, organization_id: membership.organization_id).empty?
      }
    end

    after_transition on: :activate do |membership, transition|
      membership.set activated_at: Time.now
    end
  end

  # Delivers the membership invite email
  #
  # @return [Mail::Message]
  def send_invite
    Milkyway::TransactionalEmailer.membership_invite(self).deliver
  end

  def all_listing_ids
    return organization.cached_listing_ids if all_listings
    listing_ids
  end

  def check_in_only
    check_in && !edit && !manage && !design && !promote
  end

  private

  def duplicate_email
    if organization.memberships.where(email: email).length > 0
      errors.add(:email, "already is a member")
    end
  end

  def owner_email
    if email.downcase == organization.owner.email.downcase
      errors.add(:email, "belongs to the organization owner")
    end
  end

  def creatable_has_all_permissions
    if creatable && (self.class.createable_permission_fields - exclude_toggled_permissions).find{|key| !self[key]}.present?
      errors.add(:creatable, "All event permissions must be allowed")
    end
  end

  def below_limit
    if organization.memberships.length > Organization::MAX_MEMBERSHIPS
      errors.add(:organization_max, "Maximum memberships for this organization reached")
    end
  end

  # Finds and sets an existing Uniiverse user matching email on the
  # membership
  #
  # @return [User] if a user was found
  # @return [nil] if no user found
  def find_user
    self.user ||= begin
      User.find_by(email: email.downcase)
    rescue Mongoid::Errors::DocumentNotFound
      nil
    end
  end

  # # Calls activate event or schedules a job to send an invite
  # #
  # # @return [String] if a user was not found
  # # @return [Boolean] if a user was found
  def activate_or_invite
    if user
      activate
    end
    MembershipInvitationWorker.perform_async(self.id.to_s)
  end

  # Ensures that emails are downcased and stripped of whitespace
  #
  # @return [String]
  def sanitize_email
    self.email = email.downcase.strip
  end
end
