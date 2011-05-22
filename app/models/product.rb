# encoding: utf-8
class Product < ActiveRecord::Base
  belongs_to :shop
  has_many :photos             , dependent: :destroy
  has_many :variants           , dependent: :destroy           , class_name: 'ProductVariant'
  has_many :options            , dependent: :destroy           , class_name: 'ProductOption'          , order: :position.asc
  has_many :collection_products, dependent: :destroy           , class_name: 'CustomCollectionProduct'
  has_many :collections        , class_name: 'CustomCollection', through: :collection_products        , source: :custom_collection
  has_and_belongs_to_many :tags
  # 标签
  attr_accessor :tags_text

  accepts_nested_attributes_for :photos  , allow_destroy: true
  accepts_nested_attributes_for :variants, allow_destroy: true
  accepts_nested_attributes_for :options, allow_destroy: true

  validates_presence_of :title, :product_type, :vendor

  before_create do
    if self.options.empty?
      option_name = KeyValues::Product::Option.first.name
      self.options.build name: option_name
      self.variants.first.option1 = "默认#{option_name}"
    end
  end

  before_save do
    self.handle = 'handle'
    # 新增的选项默认值要设置到所有款式中
    self.options.each_with_index do |option, index|
      next if option.value.blank?
      self.variants.each do |variant|
        variant.send "option#{index+1}=", option.value
      end
    end
  end

  def tags_text
    @tags_text ||= tags.map(&:name).join(', ')
  end

  after_save do
    product_tags = self.tags.map(&:name)
    # 删除tag
    (product_tags - Tag.split(tags_text)).each do |tag_text|
      tag = shop.tags.where(name: tag_text).first
      tags.delete(tag)
    end
    # 新增tag
    (Tag.split(tags_text) - product_tags).each do |tag_text|
      tag = shop.tags.where(name: tag_text).first
      if tag
        # 更新时间，用于显示最近使用过的标签
        tag.touch
      else
        tag = shop.tags.create name: tag_text unless tag
      end
      self.tags << tag
    end
  end
end

#商品款式
class ProductVariant < ActiveRecord::Base
  belongs_to :product
  validates_presence_of :price, :weight

  def options
    [option1, option2, option3].compact
  end

  def inventory_policy_name
    KeyValues::Product::Inventory::Policy.find_by_code(inventory_policy).name
  end
end

#商品选项
class ProductOption < ActiveRecord::Base
  belongs_to :product
  #辅助值，用于保存至商品款式中
  attr_accessor :value
end

CustomCollection
