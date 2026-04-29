# typed: false

class Profile < ApplicationRecord
  has_one :matching_criterion, dependent: :destroy
  has_many :search_queries, dependent: :destroy
  has_many :leads, dependent: :destroy

  validates :full_name, presence: true
  validates :email, presence: true

  accepts_nested_attributes_for :matching_criterion, allow_destroy: false
end
