# typed: true

module ActiveRecord
  class Base
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
    def self.acts_as_list(**opts); end

    def id; end
    def id=(v); end
    def new_record?; end
    def persisted?; end
    def destroyed?; end
    def save; end
    def save!; end
    def update(attrs); end
    def update!(attrs); end
    def destroy; end
    def destroy!; end
    def reload; end
    def errors; end
    def valid?; end
    def invalid?; end
    def toggle(name); end
    def assign_attributes(attrs); end
    def attributes; end
    def [](name); end
    def []=(name, v); end
    def changed?; end
    def changes; end
    def previous_changes; end
    def touch(name = nil); end
  end

  class Migration
    def self.[](version); end
    def change; end
    def up; end
    def down; end
    def reversible; end
    def create_table(name, **opts, &block); end
    def drop_table(name, **opts); end
    def change_table(name, **opts, &block); end
    def add_column(table, name, type, **opts); end
    def remove_column(table, name, type = nil, **opts); end
    def change_column(table, name, type, **opts); end
    def rename_column(table, old, new); end
    def add_index(table, columns, **opts); end
    def remove_index(table, **opts); end
    def rename_index(table, old, new); end
    def add_foreign_key(from, to, **opts); end
    def remove_foreign_key(from, **opts); end
    def add_reference(table, ref, **opts); end
    def remove_reference(table, ref, **opts); end
    def execute(sql); end
  end
end

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

module ActiveJob
  class Base
    def self.queue_as(name); end
    def self.retry_on(exception, **opts); end
    def self.discard_on(exception, **opts); end
    def self.set(opts); end
    def self.perform_later(*args); end
    def self.perform_now(*args); end
    def perform(*args); end
  end
end

class ApplicationJob < ActiveJob::Base
end

module ActionMailer
  class Base
    def self.mailer_defaults(*args); end
    def self.helper(*args); end
    def mail(headers = {}, &block); end
  end
end

class ApplicationMailer < ActionMailer::Base
end

module ActionController
  class Base
    def self.before_action(*args); end
    def self.skip_before_action(*args); end
    def self.after_action(*args); end
    def self.around_action(*args); end
    def self.helper_method(*args); end
    def self.rescue_from(*args); end
    def self.add_flash_types(*types); end
    def self.layout(name); end
    def self.allow_browser(**opts); end
    def render(*args); end
    def redirect_to(*args); end
    def head(*args); end
    def send_data(*args); end
    def send_file(*args); end
    def respond_to(*args); end
    def params; end
    def request; end
    def response; end
    def session; end
    def cookies; end
    def flash; end
    def current_user; end
    def logged_in?; end
    def headers; end
  end
end

class ApplicationController < ActionController::Base
end

module Rails
  def self.env; end
  def self.application; end
  def self.root; end
  def self.logger; end
  def self.cache; end
  def self.configuration; end
  def self.version; end
  def self.backtrace_cleaner; end
  def self.groups(*groups); end
  def self.env=(env); end
  def self.application=(app); end
  def self.root=(root); end
  def self.logger=(logger); end
  def self.cache=(cache); end
  def self.configuration=(config); end
  def self.backtrace_cleaner=(cleaner); end
end

module ActiveSupport
  class Duration
    def ago; end
    def from_now; end
    def until(time); end
    def since(time); end
    def +(other); end
    def -(other); end
    def *(other); end
    def /(other); end
    def <=>(other); end
    def ==(other); end
    def eql?(other); end
    def hash; end
    def inspect; end
    def to_i; end
    def to_f; end
    def to_s; end
    def parts; end
    def value; end
    def variable?; end
  end

  class TimeWithZone
    def utc; end
    def local; end
    def now; end
    def today; end
    def yesterday; end
    def tomorrow; end
    def current; end
    def zone; end
    def parse(str); end
    def at(*args); end
    def parse_with_infinity(str); end
  end

  module Concern
    def self.extended(base); end
    def included(base = nil, &block); end
    def prepended(base = nil, &block); end
    def class_methods(&block); end
  end
end

class Integer
  def seconds; end
  def minutes; end
  def hours; end
  def days; end
  def weeks; end
  def months; end
  def years; end
  def second; end
  def minute; end
  def hour; end
  def day; end
  def week; end
  def month; end
  def year; end
end
