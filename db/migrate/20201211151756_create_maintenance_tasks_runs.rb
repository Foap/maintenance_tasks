# frozen_string_literal: true

# One table, one migration. Upstream reaches this shape through six migrations,
# because it accumulated them release by release over two years, and a host app
# installing the engine today would copy all six to build a table that has never
# existed in any other form. Collapsed here to the shape they add up to:
#
#   20210225152418  drops the standalone task_name index the create added
#   20210517131953  arguments
#   20211210152329  lock_version
#   20220706101937  tick_count / tick_total widened to bigint
#   (fork)          summary
#
# Tagged [5.2] rather than [6.0]: this fork exists to run on Rails 5.2, which
# rejects a migration declaring a version it does not know.
class CreateMaintenanceTasksRuns < ActiveRecord::Migration[5.2]
  def change
    create_table(:maintenance_tasks_runs) do |t|
      t.string(:task_name, null: false)
      t.datetime(:started_at)
      t.datetime(:ended_at)
      t.float(:time_running, default: 0.0, null: false)
      t.bigint(:tick_count, default: 0, null: false)
      t.bigint(:tick_total)
      t.string(:job_id)
      t.bigint(:cursor)
      t.string(:status, default: :enqueued, null: false)
      t.string(:error_class)
      t.string(:error_message)
      t.text(:backtrace)
      t.text(:arguments)
      t.integer(:lock_version, default: 0, null: false)
      # Counters a Task accumulated while running — see Task#summary. Upstream has
      # no equivalent at any version.
      t.text(:summary)
      t.timestamps

      # Only the composite index: upstream's standalone one on task_name was
      # redundant with this one's leading column and was dropped a release later.
      t.index([:task_name, :created_at], order: { created_at: :desc })
    end
  end
end
