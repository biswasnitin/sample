class OrganizationSerializer < Api::V2::Base
  cached false

  attributes :id, :name, :features, :force_host_to_pay_commission, :has_business_info

  has_one   :owner,       serializer: UserSerializer,        embed: :objects, include: true

  attribute \
  def membership_ids
    object.memberships.distinct :id
  end

  attribute \
  def user_ids
    object.memberships.distinct :user_id
  end

  def has_business_info
    object.business_info.present?
  end
end
