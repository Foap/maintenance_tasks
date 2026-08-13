# frozen_string_literal: true

require "active_record/railtie"

module MaintenanceTasks
  # Whether the host application autoloads with Zeitwerk.
  #
  # `Rails.autoloaders` only exists from Rails 6.0. On Rails 5.2 there is no
  # Zeitwerk at all, so the answer is always false and the engine takes its
  # classic-autoloader path. Asking through this method instead of calling
  # `Rails.autoloaders` directly is what lets the engine boot on 5.2 without
  # redefining anything on ::Rails in the host application.
  def self.zeitwerk_enabled?
    defined?(Rails.autoloaders) && Rails.autoloaders.zeitwerk_enabled?
  end

  # The engine's main class, which defines its namespace. The engine is mounted
  # by the host application.
  class Engine < ::Rails::Engine
    isolate_namespace MaintenanceTasks

    # Upstream deprecation warning for classic mode removed: this fork exists to
    # run on Rails 5.2, where classic is the only autoloader available. The
    # warning would fire on every boot to report a deliberate choice.

    initializer "maintenance_tasks.configs" do
      MaintenanceTasks.backtrace_cleaner = Rails.backtrace_cleaner
    end

    config.to_prepare do
      # Upstream eager loads the engine from an initializer, which runs once per
      # boot. That is enough in production but not in a reloading environment:
      # ActiveSupport::Dependencies.clear wipes every autoloaded engine constant
      # between requests, and nothing puts them back. What follows is a
      # MaintenanceTasks::TasksController that cannot resolve Run — classic then
      # walks up to the top-level ::Run and loads whatever unrelated file the host
      # application happens to map that to — and Task subclasses left attached to a
      # stale superclass, missing ActiveModel::Attributes and so `attribute_names`.
      #
      # to_prepare runs on every reload, so the engine is rebuilt each time. It must
      # also come before the app's tasks are required, so each Task subclass attaches
      # to the MaintenanceTasks::Task loaded in this same pass.
      unless MaintenanceTasks.zeitwerk_enabled?
        eager_load!

        tasks_module = MaintenanceTasks.tasks_module.underscore
        Dir["#{Rails.root}/app/tasks/#{tasks_module}/*.rb"].each do |file|
          require_dependency(file)
        end
      end

      _ = TaskJobConcern # load this for JobIteration compatibility check
    end

    config.after_initialize do
      JobIteration.max_job_runtime ||= 5.minutes
    end

    config.action_dispatch.rescue_responses.merge!(
      "MaintenanceTasks::Task::NotFoundError" => :not_found,
    )
  end
end
