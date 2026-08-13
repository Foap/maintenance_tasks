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

    initializer "maintenance_tasks.eager_load_for_classic_autoloader" do
      eager_load! unless MaintenanceTasks.zeitwerk_enabled?
    end

    initializer "maintenance_tasks.configs" do
      MaintenanceTasks.backtrace_cleaner = Rails.backtrace_cleaner
    end

    config.to_prepare do
      _ = TaskJobConcern # load this for JobIteration compatibility check
      unless MaintenanceTasks.zeitwerk_enabled?
        tasks_module = MaintenanceTasks.tasks_module.underscore
        Dir["#{Rails.root}/app/tasks/#{tasks_module}/*.rb"].each do |file|
          require_dependency(file)
        end
      end
    end

    config.after_initialize do
      JobIteration.max_job_runtime ||= 5.minutes
    end

    config.action_dispatch.rescue_responses.merge!(
      "MaintenanceTasks::Task::NotFoundError" => :not_found,
    )
  end
end
