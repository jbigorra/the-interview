# typed: true

# Base Rails classes that Tapioca doesn't generate automatically.
# These are required for Sorbet to resolve constants in our app code.

module ActiveRecord
  class Base
    extend T::Sig

    def self.belongs_to(name, **opts); end
    def self.has_one(name, **opts); end
    def self.has_many(name, **opts); end
    def self.has_and_belongs_to_many(name, **opts); end
    def self.validates(*attrs); end
    def self.validate(*args); end
    def self.before_validation(*args); end
    def self.after_validation(*args); end
    def self.before_save(*args); end
    def self.after_save(*args); end
    def self.before_create(*args); end
    def self.after_create(*args); end
    def self.before_update(*args); end
    def self.after_update(*args); end
    def self.before_destroy(*args); end
    def self.after_destroy(*args); end
    def self.scope(name, body); end
    def self.enum(name, **opts); end
    def self.find(id); end
    def self.find_by(attrs); end
    def self.where(attrs); end
    def self.order(*args); end
    def self.limit(n); end
    def self.count; end
    def self.exists?(attrs); end
    def self.create(attrs); end
    def self.create!(attrs); end
    def self.first; end
    def self.last; end
    def self.all; end
    def self.destroy_all; end
    def self.transaction(&block); end
    def self.table_name=(name); end
    def self.primary_key=(key); end
    def self.default_scope(&block); end
    def self.attribute(name, type = nil, **opts); end
    def self.store(name, **opts); end
    def self.serialize(name, **opts); end
    def self.delegate(*args); end
    def self.ignored_columns=(cols); end
    def self.abstract_class=(val); end
    def self.abstract_class; end
    def self.connection; end
    def self.table_name; end
    def self.primary_key; end
    def self.columns; end
    def self.column_names; end
    def self.attribute_names; end
    def self.human_attribute_name(attr); end
    def self.model_name; end
    def self.reflect_on_association(name); end
    def self.reflect_on_all_associations; end
    def self.reset_column_information; end
    def self.unscoped; end
    def self.pick(*columns); end
    def self.pluck(*columns); end
    def self.select(*fields); end
    def self.group(*columns); end
    def self.having(conditions); end
    def self.joins(*args); end
    def self.left_joins(*args); end
    def self.left_outer_joins(*args); end
    def self.includes(*args); end
    def self.eager_load(*args); end
    def self.preload(*args); end
    def self.references(*args); end
    def self.distinct(value = true); end
    def self.readonly(value = true); end
    def self.lock(locks = true); end
    def self.from(clause); end
    def self.grouping; end
    def self.reorder(*args); end
    def self.reverse_order; end
    def self.none; end
    def self.unscope(*args); end
    def self.or(other); end
    def self.merge(other); end
    def self.create_with(value); end
    def self.extending(*modules); end
    def self.with(options); end
    def self.with_options(options); end
    def self.acts_as_list(**opts); end
    def self.has_secure_password(**opts); end
    def self.has_rich_text(name); end
    def self.has_one_attached(name, **opts); end
    def self.has_many_attached(name, **opts); end

    sig { returns(T.untyped) }
    def id; end

    sig { params(v: T.untyped).returns(T.untyped) }
    def id=(v); end

    sig { returns(T::Boolean) }
    def new_record?; end

    sig { returns(T::Boolean) }
    def persisted?; end

    sig { returns(T::Boolean) }
    def destroyed?; end

    sig { returns(T.untyped) }
    def save; end

    sig { returns(T.untyped) }
    def save!; end

    sig { params(attrs: T.untyped).returns(T.untyped) }
    def update(attrs); end

    sig { params(attrs: T.untyped).returns(T.untyped) }
    def update!(attrs); end

    sig { returns(T.untyped) }
    def destroy; end

    sig { returns(T.untyped) }
    def destroy!; end

    sig { returns(T.untyped) }
    def reload; end

    sig { returns(T.untyped) }
    def errors; end

    sig { returns(T::Boolean) }
    def valid?; end

    sig { returns(T::Boolean) }
    def invalid?; end

    sig { params(name: T.untyped).returns(T.untyped) }
    def toggle(name); end

    sig { params(attrs: T.untyped).returns(T.untyped) }
    def assign_attributes(attrs); end

    sig { returns(T.untyped) }
    def attributes; end

    sig { params(name: T.untyped).returns(T.untyped) }
    def [](name); end

    sig { params(name: T.untyped, v: T.untyped).returns(T.untyped) }
    def []=(name, v); end

    sig { returns(T::Boolean) }
    def changed?; end

    sig { returns(T.untyped) }
    def changes; end

    sig { returns(T.untyped) }
    def previous_changes; end

    sig { params(name: T.untyped).returns(T.untyped) }
    def touch(name = nil); end

    sig { returns(T.untyped) }
    def to_json(options = nil); end

    sig { returns(T.untyped) }
    def as_json(options = nil); end

    sig { returns(T.untyped) }
    def to_xml(options = nil); end

    sig { returns(T.untyped) }
    def to_s; end
  end
end

class ApplicationRecord < ActiveRecord::Base
  extend T::Sig
  self.abstract_class = true
end

module ActiveJob
  class Base
    extend T::Sig

    sig { params(name: T.untyped).void }
    def self.queue_as(name); end

    sig { params(exception: T.untyped, opts: T.untyped).void }
    def self.retry_on(exception, **opts); end

    sig { params(exception: T.untyped, opts: T.untyped).void }
    def self.discard_on(exception, **opts); end

    sig { params(opts: T.untyped).returns(T.untyped) }
    def self.set(opts); end

    sig { params(args: T.untyped).void }
    def self.perform_later(*args); end

    sig { params(args: T.untyped).void }
    def self.perform_now(*args); end

    sig { params(args: T.untyped).void }
    def perform(*args); end
  end
end

class ApplicationJob < ActiveJob::Base
end

module ActionMailer
  class Base
    extend T::Sig

    sig { params(args: T.untyped).void }
    def self.mailer_defaults(*args); end

    sig { params(args: T.untyped).void }
    def self.helper(*args); end

    sig { params(headers: T.untyped).void }
    def self.default(headers); end

    sig { params(headers: T.untyped).returns(T.untyped) }
    def mail(headers = {}, &block); end
  end
end

class ApplicationMailer < ActionMailer::Base
end

module ActionController
  class Base
    extend T::Sig

    sig { params(args: T.untyped).void }
    def self.before_action(*args); end

    sig { params(args: T.untyped).void }
    def self.skip_before_action(*args); end

    sig { params(args: T.untyped).void }
    def self.after_action(*args); end

    sig { params(args: T.untyped).void }
    def self.around_action(*args); end

    sig { params(args: T.untyped).void }
    def self.helper_method(*args); end

    sig { params(args: T.untyped).void }
    def self.rescue_from(*args); end

    sig { params(types: T.untyped).void }
    def self.add_flash_types(*types); end

    sig { params(name: T.untyped).void }
    def self.layout(name); end

    sig { params(opts: T.untyped).void }
    def self.allow_browser(**opts); end

    sig { params(args: T.untyped).returns(T.untyped) }
    def render(*args); end

    sig { params(args: T.untyped).returns(T.untyped) }
    def redirect_to(*args); end

    sig { params(args: T.untyped).void }
    def head(*args); end

    sig { params(args: T.untyped).void }
    def send_data(*args); end

    sig { params(args: T.untyped).void }
    def send_file(*args); end

    sig { params(args: T.untyped).void }
    def respond_to(*args); end

    sig { returns(T.untyped) }
    def params; end

    sig { returns(T.untyped) }
    def request; end

    sig { returns(T.untyped) }
    def response; end

    sig { returns(T.untyped) }
    def session; end

    sig { returns(T.untyped) }
    def cookies; end

    sig { returns(T.untyped) }
    def flash; end

    sig { returns(T.untyped) }
    def headers; end
  end
end

class ApplicationController < ActionController::Base
end
