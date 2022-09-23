class Customer < ApplicationRecord
  include Elasticsearch::Model
  # レコードが更新したタイミングでESのドキュメントも更新してくれる
  # TODO: 同期的処理なので、sidekiqなど使用し非同期に変更する
  include Elasticsearch::Model::Callbacks
  include EmailHolder
  include PersonalNameHolder
  include PasswordHolder

  has_many :addresses, dependent: :destroy
  has_many :messages
  has_many :outbound_messages, class_name: "CustomerMessage",
    foreign_key: "customer_id"
  has_many :inbound_messages, class_name: "StaffMessage",
    foreign_key: "customer_id"
  has_one :home_address, autosave: true
  has_one :work_address, autosave: true
  has_many :phones, dependent: :destroy
  has_many :personal_phones, -> { where(address_id: nil).order(:id) },
    class_name: "Phone", autosave: true
  has_many :entries, dependent: :destroy
  has_many :programs, through: :entries

  validates :gender, inclusion: { in: %w(male female), allow_blank: true }
  validates :birthday, date: {
    after: Date.new(1900, 1, 1),
    before: ->(obj) { Date.today },
    allow_blank: true
  }

  before_save do
    if birthday
      self.birth_year = birthday.year
      self.birth_month = birthday.month
      self.birth_mday = birthday.mday
    end
  end

  # Elastic Searchで検索
  def self.es_search(query)
    __elasticsearch__.search({
      query: {
        multi_match: {
          fields: %w(family_name given_name family_name_kana given_name_kana email),
          type: 'cross_fields',
          query: query,
          operator: 'and'
        }
      }
    })
  end
end
