class MembershipSerializer < Api::V2::Base
  cached

  attributes :id,
             :organization_id,
             :token,
             :email,
             :all_listings,
             :creatable,
             :role_name,
             :activated_at,
             :created_at,
             :updated_at,
             :state,
             :listing_ids,
             :type

  # The lack of a type has been messing with the reset password functionality in multiverse.
  def type
    "membership"
  end

  attributes *Membership.permission_fields

  has_one :organization,  serializer: OrganizationSerializer,    embed: :ids,   include: false
  has_one :user,          serializer: UserSerializer,            embed: :ids,   include: false
end
