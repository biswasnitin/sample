class UserSerializer < Api::V2::Base

  cached

  attributes :id,
             :slug,
             :first_name,
             :last_name,
             :gender,
             :created_at,
             :updated_at,
             :description,
             :short_description,
             :locale,
             :verified_at,
             :manual_ref,
             :messageable

  has_one :billing_info, serializer: BillingInfoSerializer, embed: :objects, include: true

  attribute :has_avatar?, key: :has_avatar
  attribute :confirmed?, key: :confirmed
  attribute :starter_plan?, key: :starter_plan

  attributes :image_url, :image_url_500, :image_url_160, :image_url_50

  # # current user attributes

  def image_url;        object.image_url :original;     end
  def image_url_500;    object.image_url :medium;       end
  def image_url_160;    object.image_url :square;       end
  def image_url_50;     object.image_url :thumb;        end

  # this is the pre-filepicker.io way, see listing for new way
  attributes :cover_photo_url
  def cover_photo_url;  object.cover_photo_url :full;   end

  def slug
    object.to_param
  end
end
